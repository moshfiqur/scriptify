#!./venv/bin/python3

import os
import shutil
import argparse
from dotenv import load_dotenv

def organize_files(dry_run):
    """
    Copies files and folders from Desktop, Downloads, and Pictures
    to a target directory, organizing them by type.

    Args:
        dry_run (bool): If True, only print the planned operations.
    """
    # Load environment variables from .env file
    load_dotenv()

    # Use os.path.expanduser to correctly resolve the user's home directory
    home_directory = os.path.expanduser("~")

    # Define source directories relative to the home directory
    source_dirs = {
        "Desktop": os.path.join(home_directory, "Desktop"),
        "Downloads": os.path.join(home_directory, "Downloads"),
        "Pictures": os.path.join(home_directory, "Pictures")
    }

    # Get the target directory from environment variable
    target_base_dir = os.getenv("TARGET_BASE_DIR")
    if not target_base_dir:
        raise ValueError("TARGET_BASE_DIR environment variable is not set. Please check your .env file.")

    # Common image extensions to be grouped together
    image_extensions = ['.jpeg', '.jpg', '.png', '.gif', '.heic', '.webp']

    print("Starting file organization process...")
    if dry_run:
        print("--- DRY RUN MODE: No files will be moved. ---")

    # Ensure the base target directory exists
    if not dry_run and not os.path.exists(target_base_dir):
        print(f"Creating base target directory: {target_base_dir}")
        os.makedirs(target_base_dir)

    # Iterate over each source directory
    for dir_name, source_path in source_dirs.items():
        if not os.path.exists(source_path):
            print(f"Source directory not found, skipping: {source_path}")
            continue

        print(f"\nProcessing files from: {dir_name} ({source_path})")

        # Walk through all items in the source directory
        for item in os.listdir(source_path):
            source_item_path = os.path.join(source_path, item)
            
            try:
                # --- Handle Directories ---
                if os.path.isdir(source_item_path):
                    destination_folder_path = os.path.join(target_base_dir, item)
                    print(f"[Folder] '{source_item_path}' -> '{destination_folder_path}'")
                    if not dry_run:
                        # shutil.copytree will copy the entire directory recursively.
                        # `dirs_exist_ok=True` prevents errors if the destination already exists.
                        shutil.copytree(source_item_path, destination_folder_path, dirs_exist_ok=True)

                # --- Handle Files ---
                elif os.path.isfile(source_item_path):
                    # Get the file extension
                    _, file_extension = os.path.splitext(item)
                    file_extension = file_extension.lower()

                    # Determine the destination subfolder
                    if file_extension in image_extensions:
                        destination_folder_name = "Images"
                    elif file_extension: # Check if there is an extension
                        # Use the extension name (without the dot) as the folder name
                        destination_folder_name = file_extension[1:]
                    else:
                        # For files without an extension
                        destination_folder_name = "Other_Files"
                    
                    destination_folder_path = os.path.join(target_base_dir, destination_folder_name)
                    destination_file_path = os.path.join(destination_folder_path, item)

                    print(f"[File]   '{source_item_path}' -> '{destination_file_path}'")

                    if not dry_run:
                        # Create the destination subfolder if it doesn't exist
                        if not os.path.exists(destination_folder_path):
                            os.makedirs(destination_folder_path)
                        
                        # Copy the file
                        shutil.copy2(source_item_path, destination_file_path)
            
            except Exception as e:
                print(f"Error processing '{source_item_path}': {e}")


if __name__ == "__main__":
    # Set up the argument parser for command-line options
    parser = argparse.ArgumentParser(description="Organize files from Desktop, Downloads, and Pictures.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Simulate the process without moving any files. Prints source and destination paths."
    )
    args = parser.parse_args()

    organize_files(args.dry_run)
    print("\nFile organization process complete.")