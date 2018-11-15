//
//  ViewController.swift
//  Todoey
//
//  Created by 胡洞明 on 2018/5/3.
//  Copyright © 2018年 胡洞明. All rights reserved.
//

import UIKit
import CoreData
import ChameleonFramework
import SwipeCellKit

class ToDoVC: SwipeTableViewController {
    
 let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    @IBOutlet weak var searchBar: UISearchBar!
    var items: [ToDoItems] = []
    var sorttedItems: [[ToDoItems]] = [[],[],[]]
    var category : Category! {
        didSet{
            loadItemsUnderCurrentCategory()  // load all the items under current category
            navigationItem.title = category.name
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
                
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tableView.backgroundColor = UIColor(hexString: category.colorHex!)

        guard let navBar = navigationController?.navigationBar else { fatalError("No nav controller") }
//        guard let barColor = UIColor(hexString: category.colorHex) else { fatalError() }
        navBar.barTintColor = UIColor(hexString: category.colorHex!)
        navBar.tintColor = ContrastColorOf(navBar.barTintColor!, returnFlat: true)
        navBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : navBar.tintColor]
        
        searchBar.barTintColor = HexColor(category.colorHex!)
    }
    
    //MARK: - Tableview Datasource
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = super.tableView(tableView, cellForRowAt: indexPath) as! MyTableViewCell
        
        cell.textLabel?.text = items[indexPath.row].title

            switch items[indexPath.row].done {
            case "failed":
                cell.checkBox.setImage(UIImage(named: "crossed"), for: .normal)
            case "done":
                cell.checkBox.setImage(UIImage(named: "checked"), for: .normal)
            default:
                cell.checkBox.setImage(UIImage(named: "empty"), for: .normal)
            }
        
        cell.backgroundColor = UIColor(hexString: category.colorHex!)!.darken(byPercentage: (CGFloat(indexPath.row) / CGFloat(items.count)) * 0.15)
        cell.textLabel?.textColor = ContrastColorOf(cell.backgroundColor!, returnFlat: true)
        
        
        return cell
    }

    // MARK: - Tableview Delegate & Navigation
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        performSegue(withIdentifier: "ShowNotes", sender: self)
        tableView.deselectRow(at: indexPath, animated: true)   // 选中后一闪而过

    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowNotes" {
            let noteVC = segue.destination as! NotesVC
            guard let index = tableView.indexPathForSelectedRow else {fatalError("No selected row")}
            noteVC.currentItem = items[index.row]
        }
    }
    
    // MARK: - Add New Items
    
    @IBAction func addBtnPressed(_ sender: UIBarButtonItem) {
        
        var textField = UITextField()
        
        let alert = UIAlertController(title: "Add Todo Item", message: "", preferredStyle: .alert)
        
        let action = UIAlertAction(title: "Add Item", style: .default) { (action) in
            // Create newItem，Set its properties，Save
            let newItem = ToDoItems(context: self.context)
            newItem.title = textField.text
            newItem.done = "todo"
            newItem.parentCategory = self.category
            
            self.saveItems()
            self.loadItemsUnderCurrentCategory()
        }
        
        alert.addTextField { (alertTextField) in
            alertTextField.placeholder = "Create new item"
            textField = alertTextField
        }
        
        alert.addAction(action)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        
    }
    
    // MARK: - Swipe Functions
    
    // MARK:  Delete Data by Swipe to Left
    
    override func updateModel(at indexPath: IndexPath) {
        context.delete(items[indexPath.row])
        items.remove(at: indexPath.row)
        saveItems()
        tableView.reloadData()
    }
    
    // MARK: Mark Item as Failed
    
    override func failingItemAt(_ indexPath: IndexPath) {
        if items[indexPath.row].done == "failed" {
            items[indexPath.row].done = "todo"
        } else {
            items[indexPath.row].done = "failed"
        }
        saveItems()
        tableView.reloadRows(at: [indexPath], with: .left)
    }
    
    // MARK:  Change Color
    
    override func changeColor(at indexPath: IndexPath) {

        let index = Settings.palletHex.firstIndex(of: category.colorHex!)!
        category.colorHex = Settings.palletHex[(index + 1) % Settings.palletHex.count]
        saveItems()
        let cells = tableView.visibleCells
        var i = 0
        for cell in cells {
            cell.backgroundColor = HexColor(category.colorHex!)?.darken(byPercentage: CGFloat(i) / CGFloat(cells.count) * 0.15)
            i += 1
        }
        
        viewWillAppear(true)
    }
    
    // MARK: - User Tapped Checkbox
    
    @IBAction func checkBoxPressed(_ sender: UIButton) {
        let hitPoint = sender.convert(CGPoint.zero, to: tableView)
        guard let hitIndex = tableView.indexPathForRow(at: hitPoint) else { fatalError("cannot find hit index") }
        switch items[hitIndex.row].done {
        case "todo":
            items[hitIndex.row].done = "done"
        case "done":
            items[hitIndex.row].done = "todo"
        default:
            items[hitIndex.row].done = "todo"
        }
        
        saveItems()
        tableView.reloadRows(at: [hitIndex], with: .fade)
    }
    
    
    // MARK: - Data Manipulation Methods
    
    func saveItems(){
        do {
            try context.save()
            print("Changes saved")
        } catch {
            print("Error with saving: \(error)")
        }
    }
    
    func loadItemsUnderCurrentCategory(with request: NSFetchRequest<ToDoItems> = ToDoItems.fetchRequest(), _ predicate: NSPredicate? = nil){
        let categoryPredicate = NSPredicate(format: "parentCategory.name MATCHES %@", category.name!)
        
        if let predicate = predicate {
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [categoryPredicate, predicate])
            request.predicate = compoundPredicate
        } else {
            request.predicate = categoryPredicate
        }
        
        do {
            items = try context.fetch(request)
        } catch {
            fatalError("Error fetching data, \(error)")
        }
        
        for item in items {
            switch item.done {
            case "todo":
                sorttedItems[0].append(item)
            case "done":
                sorttedItems[1].append(item)
            case "failed":
                sorttedItems[2].append(item)
            default:
                break
            }
        }
        
            tableView.reloadData()
        }

}



// MARK: - Search Bar Functions

extension ToDoVC: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchByTitle()
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {  // Dynamic Search
        if searchBar.text?.count == 0 {
            loadItemsUnderCurrentCategory()
        } else {
            searchByTitle()
        }
    }
    
    func searchByTitle() {
        let request : NSFetchRequest<ToDoItems> = ToDoItems.fetchRequest()
        let predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchBar.text!)
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        loadItemsUnderCurrentCategory(with: request, predicate)
    }
}

