#!/bin/bash

# Define the root directory for databases
ROOT_DIR="./databases"


function create_table {

  echo -n "Enter table name: "
  read table_name
  
  while [ -e "$db_name/$table_name" ]; do
    echo "Table already exists. Please enter a different name."
    echo -n "Enter table name: "
    read table_name
  done

  echo -n "Enter number of columns: "
  read num_columns
  
  # Initialize metadata and data strings
  metadata="Field|Type|Key"
  data=""
  primary_key_set=false
  
  # Loop through each column and prompt for name and type
  for (( i=1; i<=$num_columns; i++ )); do
    echo -n "Enter name of column $i: "
    read col_name

    while true; do
      echo -n "Enter data type for column $col_name (1 for int, 2 for str): "
      read col_type_num

      if [[ $col_type_num == 1 ]]; then
        col_type="int"
        break
      elif [[ $col_type_num == 2 ]]; then
        col_type="str"
        break
      else
        echo "Invalid input. Please enter 1 for int or 2 for str."
      fi
    done

    # If a primary key has not been set, prompt user to set one
    if ! $primary_key_set; then
      echo -n "Make $col_name the primary key? (y/n): "
      read is_primary_key
      if [[ $is_primary_key == "y" ]]; then
        key="PK"
        primary_key_set=true
      else
        key=""
      fi
    else
      key=""
    fi

    # Add column metadata to metadata string
    metadata="$metadata\n$col_name|$col_type|$key"

    # Add column name to data string
    if [[ $i -eq $num_columns ]]; then
      data+="$col_name"
    else
      data+="$col_name|"
    fi
  done

  # If a primary key has not been set, prompt user to select one
  if ! $primary_key_set; then
    echo "No primary key column selected."
    echo "Please select a column to use as the primary key:"
    echo -e "$metadata"
    read primary_key_column

    # Set the key field in the metadata string for the primary key column
    metadata=$(echo -e "$metadata" | awk -v col="$primary_key_column" -F'|' 'BEGIN{OFS="|"}{if ($1==col) $3="PK"; print}')
  fi


  # Create metadata file in database directory
  echo -e "$metadata" > "$ROOT_DIR/$db_name/.$table_name"

  # Create data file in database directory
  echo -e "$data" > "$ROOT_DIR/$db_name/$table_name"
  
  echo "Table '$table_name' created successfully in database '$db_name'."
}



function drop_table {
    # Prompt the user to enter the name of the table to drop
    echo "Enter the name of the table to drop:"
    read table_name

    # Confirm with the user that they want to drop the table
    echo "Are you sure you want to delete the table $table_name? (y/n)"
    read confirmation

    # If the user confirms, delete the table file and metadata file
    if [ "$confirmation" == "y" ]; then
        # Check if the table file exists in the database directory
        if [ -f "$ROOT_DIR/$db_name/$table_name" ]; then
            # Delete the table file and metadata file
            rm "$ROOT_DIR/$db_name/$table_name" "$ROOT_DIR/$db_name/.$table_name" 2>>./.error.log
            # Check the exit status of the rm command to see if it was successful
            if [[ $? == 0 ]]; then
                echo "Table $table_name dropped successfully"
            else
                echo "Error dropping table $table_name"
            fi
        else
            echo "Table $table_name does not exist in the database"
        fi
    else
        echo "Table $table_name was not dropped"
    fi
}


function update {
  echo -e "Enter table name: \c"
  read tableName

  # Check if table exists
  if [[ ! -f "$ROOT_DIR/$db_name/$tableName" ]]; then
    echo "Error: Table '$tableName' does not exist."
    return 1
  fi

  echo -e "Enter condition column name: \c"
  read conditionColumn

  # Check if condition column exists
  if ! awk -F "|" '{exit !($1=="'$conditionColumn'")}' "$ROOT_DIR/$db_name/$tableName" >/dev/null; then
    echo "Error: Condition column '$conditionColumn' does not exist in table '$tableName'."
    return 1
  fi

  echo -e "Enter condition value: \c"
  read conditionValue

  echo -e "Enter column name to update: \c"
  read updateColumn

  # Check if column to update exists
  if ! awk -F "|" '{exit !($1=="'$updateColumn'")}' "$ROOT_DIR/$db_name/$tableName" >/dev/null; then
    echo "Error: Column to update '$updateColumn' does not exist in table '$tableName'."
    return 1
  fi

  # Find column index in metadata file
  declare -i columnIndex
  columnIndex=$(awk -F "|" -v col="$updateColumn" '$1==col{print $2; exit}' "$ROOT_DIR/$db_name/.$tableName")

  # Check if column index was found
  if [[ -z "$columnIndex" ]]; then
    echo "Error: Could not find index for column '$updateColumn' in metadata file."
    return 1
  fi

  echo -e "Enter new value: \c"
  read newValue

  # Update rows
  awk -F "|" -v conditionColumn="$conditionColumn" -v conditionValue="$conditionValue" -v columnIndex="$columnIndex" -v newValue="$newValue" '$(columnIndex[conditionColumn]) == conditionValue {$(columnIndex) = newValue} {print}' "$ROOT_DIR/$db_name/$tableName" > "$ROOT_DIR/$db_name/$tableName.tmp"

  # Replace original file with updated file
  mv "$ROOT_DIR/$db_name/$tableName.tmp" "$ROOT_DIR/$db_name/$tableName"

  echo "Row updated successfully."
}



function delete {
 # Prompt the user to enter the name of the database
  echo  "Enter the name of the database: \c"
  read dbn

  # Check if the database directory exists
  if [[ ! -d "$ROOT_DIR/$dbn" ]]; then
    echo "Database $dbn does not exist."
    return
  fi

  # List the tables in the database
  echo "Tables in database $dbn:"
  ls "$ROOT_DIR/$dbn"

  # Prompt the user to select a table to delete from
  echo -e "Enter the name of the table to delete from: \c"
  read tName

  # Check if the table exists in the database directory
  if [[ ! -f "$ROOT_DIR/$dbn/$tName" ]]; then
    echo "Table $tName does not exist in the database $dbn"
    return
  fi

  # Read the metadata for the table to get the column names and data types
  metadata_file="$ROOT_DIR/$dbn/.$tName"
  column_names=($(awk -F "|" '{print $1}' "$metadata_file"))

  # Prompt user to enter condition column name
  echo -e "Enter Condition Column name: \c"
  # Read condition column name from user input
  read column

  # Check if the condition column exists in the table
  if ! [[ " ${column_names[@]} " =~ " ${column} " ]]; then
    echo "Column $column does not exist in table $tName."
    return
  fi

  # Prompt user to enter condition value
  echo -e "Enter Condition Value: \c"
  # Read condition value from user input
  read value

  # Find the rows in the table where the condition column has the same value as the user input
  # The awk command prints the row numbers where the condition is true
  matching_rows=$(awk -v col="$column" -v val="$value" -F "|" '$col == val {print NR}' "$ROOT_DIR/$dbn/$tName")

  # If no rows match the condition, print an error message and return to the main menu
  if [[ -z "$matching_rows" ]]; then
    echo "Value Not Found"
    return
  fi

  # Prompt user to confirm the deletion
  echo "The following rows will be deleted:"
  awk -v col="$column" -v val="$value" -F "|" 'BEGIN{OFS="|"}$col == val {print}' "$ROOT_DIR/$dbn/$tName"
  read -p "Are you sure you want to delete these rows? (y/n): " confirm_delete

  if [[ $confirm_delete == "y" ]]; then
    # Delete the matching rows from the table data file
    awk -v col="$column" -v val="$value" -F "|" '$col != val {print}' "$ROOT_DIR/$dbn/$tName" > "$ROOT_DIR/$dbn/$tName.tmp"
    mv "$ROOT_DIR/$dbn/$tName.tmp" "$ROOT_DIR/$dbn/$tName"
    echo "Rows deleted successfully from table $tName."
  else
    echo "Deletion canceled."
  fi
}



# Define the menu function to display options
function menu() {
    clear
    echo -e "\e[32m=========================================================================================\e[0m"
    echo -e "\e[32m=          Welcome to our Database Management System using bash commands           =\e[0m"
    echo -e "\e[32m=========================================================================================\e[0m"
    echo ""
    echo -e "\e[33mSelect an option:\e[0m"
    echo ""
    echo -e "\e[33m1. Create database\e[0m"
    echo -e "\e[33m2. List databases\e[0m"
    echo -e "\e[33m3. Drop database\e[0m"
    echo -e "\e[33m4. Connect to database\e[0m"
    echo -e "\e[33m5. Exit\e[0m"
    echo ""
    echo -e "\e[32m====================================\e[0m"
}

# Define the function to create a new database
function create_database() {
    echo "Enter the name of the new database:"
    read db_name
    if [[ "$db_name" =~ ^[0-9] ]] || [[ "$db_name" =~ [^[:alnum:]_] ]]; then
        echo "Database name cannot start with a number or contain special characters"
        return
    fi
    
    db_dir="$ROOT_DIR/$db_name"
    if [ -d "$db_dir" ]; then
        echo "Database already exists: $db_name"
        return
    fi
    mkdir -p "$db_dir"
    echo "Database created: $db_name"
}

# Define the function to list all databases
function list_databases() {
    ls "$ROOT_DIR"
}

# Define the function to drop a database
function drop_database() {
    echo "Enter the name of the database to drop:"
    read db_name
    db_dir="$ROOT_DIR/$db_name"
    if [ ! -d "$db_dir" ]; then
        echo "Database not found: $db_name"
        read -p "Do you want to create a database with this name? (y/n)" choice
        if [ "$choice" == "y" ]; then
            create_database "$db_name"
        fi
        return
    fi
    echo "Are you sure you want to delete the database $db_name? (y/n)"
    read confirmation
    if [ "$confirmation" == "y" ]; then
        rm -rf "$db_dir"
        echo "Database dropped: $db_name"
    else
        echo "Operation cancelled"
    fi
}



function list {

  # List all files in the database directory that are not metadata files
  echo "Tables in database $db_name:"
  ls -p "$ROOT_DIR/$db_name" | grep -v / | grep -v "^\." | sed 's/\(.*\)/\t\1/'
}




# Define the function to connect to a database
function connect_database() {
    echo "Enter the name of the database to connect to:"
    read db_name
    db_dir="$ROOT_DIR/$db_name"
    if [ ! -d "$db_dir" ]; then
        echo "Database not found: $db_name"
        read -p "Do you want to create a database with this name? (y/n)" choice
        if [ "$choice" == "y" ]; then
            create_database "$db_name"
        fi
        return
    fi

    while true
    do
        clear
        echo -e "\e[32m=========================================\e[0m"
        echo -e "\e[32m=  Connected to database: $db_name\e[0m"
        echo -e "\e[32m=========================================\e[0m"
        echo ""
        echo -e "\e[33mSelect an option:\e[0m"
        echo ""
        echo -e "\e[33m1. Create table\e[0m"
        echo -e "\e[33m2. List tables\e[0m"
        echo -e "\e[33m3. Drop table\e[0m"
        echo -e "\e[33m4. Insert into table\e[0m"
        echo -e "\e[33m5. Delete from table\e[0m"
        echo -e "\e[33m6. Update table\e[0m"
        echo -e "\e[33m7. Rename database\e[0m"
        echo -e "\e[33m8. Exit\e[0m"
        echo ""
        echo -e "\e[32m=========================================\e[0m"


        read choice

        case $choice in
            1) create_table ;;
                
            
            2)
               list
                ;;
            3)  drop_table
                ;;
            4)insert;;
   


            5)
                delete
                ;;
            6)
                update
                ;;
            7)
                echo "Enter the new name for the database:"
                read new_db_name
                if [[ "$new_db_name" =~ ^[0-9] ]] || [[ "$new_db_name" =~ [\!\@\#\$\%\^\&\*\(\)\+\=\-\{\}\;\:\'\"\|\\\,\.\<\>\/\?] ]];                then
                    echo "Invalid database name"
                    return
                fi
                mv "$db_dir" "$ROOT_DIR/$new_db_name"
                echo "Database renamed to: $new_db_name"
                db_name=$new_db_name
                db_dir="$ROOT_DIR/$db_name"
                ;;
            8)
                echo "Exiting"
                return
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac

        read -p "Press enter to continue"
    done
}

# Main loop
while true
do
    menu
    read choice

    case $choice in
        1)
            create_database
            ;;
        2)
            list_databases
            ;;
        3)
            drop_database
            ;;
        4)
            connect_database
            ;;
        5)
           exit
             ;;

        *)
            echo "Invalid option"
            ;;
    esac

    echo "Press enter to continue"
    read
done
