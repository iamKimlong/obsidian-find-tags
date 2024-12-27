# find-tags-obsidian
This is a shell script to find any tags inside a specified directory.

## Usage

There are 2 available functions:
`. find-tags.sh --list-tags`
`. find-tags.sh --search '#tag'`

The first function list all available tags in all .md files within the specified directory (can change in the script)

The second function search for files that contain that specific tags

## Additional Info

Although this could be done with ripgrep, the `--list-tags` function can list distinct tags just like in *Obsidian*. The `--search` function can be done easily with ripgrep or telescope live grep in neovim.
