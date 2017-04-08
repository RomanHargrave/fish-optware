# fish-optware

Caching system for automatic path inclusion!

fish-optware is tool that searches a set list of directories
(`__fish_optware_search_dirs`) for directories containing executables.

It maintains a cache of directories so as to not repeat the search
at every shell startup, and allows you to configure on a per-directory basis
where files should be found.

# usage

To build the cache, you will want to run `optware rebuild`.
You may want to run `optware search` first, to see what it finds.

After building the cache, your software will be in the search path on 
next launch (or next time you source `02_locate_user_optware.fish`).

To show what is currently in the cache, run `optware list`.

## search specifics

When looking for files, fish-optware looks for specific directries at
a default depth of 3 folders under each optware subdirectory.

The specific directory names it will look for by default are `bin` and `bin64`.
It will also check to see if the subdirectory contains executable files immediately
beneath it, and add it if that is the case.

If you want to tell fish-optware to look for different directories (like `bin32`)
you should set `__fish_optware_common_bindirs` to meet your needs. 

If you want fish-optware to search deeper than three levels, you may set `__fish_optware_binsearch_depth`
to your desired depth.

## per-directory configuration

The search algorithm will look for `.optware_path` 
(what `__fish_optware_path_file` is set to) immediately under each 
directory in `__fish_optware_search_dirs`.

If this file exists, its contents will be used as the search data for
that directory instead of searching the directory.

Each line in this file is a single path, _relative_ to location of the file,
for example, if you have a folder `/opt/application`, and a 
file `/opt/application/.optware_path` that contains the following two lines,

```
lib/libexec
bin64
```

These will be absolutized to `/opt/application/lib/libexec` 
and `/opt/application/bin64`, then included in to the cache as those 
absolute paths.

Consequently, if you want a directory to be ignored, you can simply
place an empty `.optware_path` file in it.
