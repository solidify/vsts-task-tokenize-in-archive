# Tokenize in Archive

This task is used to replace tokens in an archive file. The task is configured with match patterns which will be replaced with values from variables in the build or release definition.

## Limitations / Missing features ##
- Only .zip archive format is supported (we use System.IO.Compression.ZipFile)
- The task is using powershell and runs where powershell can run and necessary libraries are available (not cross-platform)
- We do not have explicit encoding handling implemented

## Usage ##

Add a new task and select **Tokenize in Archive** from the **Utility** category and configure as needed.

![screenshot](img/configure-task.png)

Parameters:
- **Path** - Base path to packages. A recursive search will be performed from this path.
- **Packages** - Package file name pattern to look for. I.e. *.zip.
- **FilesToTokenize** - File name pattern to look for inside a package. I.e. web.config.
- **Prefix** - Token prefix
- **Suffix** - Token suffix
- **ReplaceWithEmpty** - If token is not found, replace with empty value. (Default is to keep the token) 
