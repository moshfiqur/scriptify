# Scriptify

A collection of utility scripts to help automate common file management tasks.

## 🚀 Features

### 📁 [Cleanup](./cleanup/)
Recursively clean project directories by removing common build artifacts and dependencies.

**What it does:**
- Removes `node_modules` folders (Node.js dependencies)
- Removes `.git` folders (Git repositories)
- Removes `build` folders (Build artifacts)

**Usage:**
```bash
cd cleanup
./clean_proj_dir.sh /path/to/your/projects_folder
./clean_proj_dir.sh /path/to/your/projects_folder --dry-run
```

### 📂 [Organize Docs](./organize_docs/)
Automatically organize files from Desktop, Downloads, and Pictures into a structured directory by file type.

**What it does:**
- Organizes files by extension (Images, PDF, TXT, etc.)
- Groups common image formats together
- Skips files that already exist (saves disk writes)
- Supports dry-run mode for testing

**Usage:**
```bash
cd organize_docs
./organize.py --dry-run  # Preview what will be organized
./organize.py            # Actually organize the files
```

## 🛠️ Setup

### Prerequisites
- **Cleanup script**: Bash shell (macOS/Linux)
- **Organize script**: Python 3 with `python-dotenv` package

### Installation

1. Clone or download this repository
2. For the organize script, install dependencies:
   ```bash
   pip install python-dotenv
   ```
3. Configure the organize script:
   ```bash
   cd organize_docs
   cp .env.example .env
   # Edit .env with your target directory path
   ```

## 📋 Configuration

### Organize Docs Configuration
Create a `.env` file in the `organize_docs` directory:
```bash
TARGET_BASE_DIR=/path/to/your/target/directory
```

## 🔧 Features

- **Safe operations**: Both scripts support dry-run mode
- **User confirmation**: Cleanup script asks for confirmation before deletion
- **Incremental processing**: Organize script skips existing files
- **Detailed logging**: Clear output showing what actions are taken
- **Error handling**: Graceful handling of missing directories and files

## 📁 Project Structure

```
scriptify/
├── README.md
├── cleanup/
│   └── clean_proj_dir.sh      # Project directory cleaner
├── organize_docs/
│   ├── organize.py            # File organizer script
│   ├── .env.example          # Configuration template
│   └── .env                  # Your configuration (create this)
└── .gitignore
```

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📄 License

This project is open source and available under the [MIT License](LICENSE).
