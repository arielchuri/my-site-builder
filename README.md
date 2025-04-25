# Building a site from partial files

```
   _____          _________.__  __        __________      .__.__       .___            
  /     \ ___.__./   _____/|__|/  |_  ____\______   \__ __|__|  |    __| _/___________ 
 /  \ /  <   |  |\_____  \ |  \   __\/ __ \|    |  _/  |  \  |  |   / __ |/ __ \_  __ \
/    Y    \___  |/        \|  ||  | \  ___/|    |   \  |  /  |  |__/ /_/ \  ___/|  | \/
\____|__  / ____/_______  /|__||__|  \___  >______  /____/|__|____/\____ |\___  >__|   
        \/\/            \/               \/       \/                    \/    \/       


```

The bash script _build.sh_ takes the files in _input_, merges them with the files in _partials_ and places the new files in _public_.

This allows you to keep your site's head, header, and footer as separate files from the content.

## Features:
 - Recursive processing of HTML from input/ to public/
 - Uses partials/_head.html, _header.html, _footer.html for page structure
 - Sets <title> from <body id=""> or filename (hyphens to spaces, title case)
 - Copies other asset files unchanged
 - Only processes/copies files that are missing or changed (incremental build)
 - Injects a JS snippet into HTML footer for live reload (auto refresh)
 - Options:
     --clean       : delete public/ folder before building
     --dry-run     : show planned actions but don't write files
     --serve       : run python3 http.server on localhost:8000 after build
     --watch       : watch input/ and partials/ for changes, auto rebuild (needs inotifywait from inotify-tools)
     --no-refresh  : disable injecting live reload JS
     --help        : show help
  
## Dependencies:
 - python3 (for --serve)
 - inotifywait (for --watch, from inotify-tools package)

## Usage examples:
sh ./build.sh --no-refresh # to process files for distribution.
sh ./build.sh --serve # to create a server to view the site in a browser. Create a new terminal for further commands.
sh ./build.sh --watch # to watch for changes and process them as they happen.

## Information
Copyright 2025 Ariel Churi
MIT license (You can use this code any way you like as long as you include the license so that others may use it too.)
