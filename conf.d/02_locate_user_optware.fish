# vim: set ts=4 sw=4 :
# Search path, modifiable by setting before snippet is loaded
if not set -q __fish_optware_search_dirs 
    set -x __fish_optware_search_dirs $LFIX/opt /opt
end

# Cache location
set -x __fish_optware_cache_dir         $HOME/.cache/fish-optware-repo
set -x __fish_optware_cache_bin         $__fish_optware_cache_dir/bin
set -x __fish_optware_path_file         $__fish_optware_cache_dir/path
set -x __fish_optware_override_name     .optware_path
set -x __fish_optware_exports_name      .optware_export

if not set -q __fish_optware_common_bindirs
   set -x __fish_optware_common_bindirs bin bin64
end

if not set -q __fish_optware_binsearch_depth
   set -x __fish_optware_binsearch_depth   3
end

if [ ! -d $__fish_optware_cache_dir ]
    mkdir -p $__fish_optware_cache_dir
end

# Helpers
function __fish_optware.conf.path_insert
    for spec in $argv
        if not contains $spec $PATH
            set -gx PATH $PATH $spec
        end
    end
end

# Search Logic
# All output via stdout

# Precompile findargs for build_path_for_dir
set __fish_optware__build_path_for_dir__findargs -mindepth 1 -maxdepth $__fish_optware_binsearch_depth -type d (string split ' ' -- (echo '-name '$__fish_optware_common_bindirs' -not -empty -or' | grep -Po '^.*(?= -or)'))
function __fish_optware.build_path_for_dir -a dir 
    # If a custom path config for this dir exists, 
    if [ -f "$dir/$__fish_optware_override_name" ]
        pushd $dir
            for relpath in (cat $dir/$__fish_optware_override_name)
                echo (realpath $relpath)
            end
        popd
    else 
        # Build find args
        for subdir in (find $dir $__fish_optware__build_path_for_dir__findargs)
            echo $subdir
        end

        # Test for executable files in root of $dir, because that happens
        if count (find $dir -maxdepth 1 -type f -executable) >/dev/null ^&1
            echo $dir
        end
    end
end

# All output is absolute
function __fish_optware.build_cache
    for opt_dir in $__fish_optware_search_dirs 
        for dir in (find $opt_dir -mindepth 1 -maxdepth 1 -type d)
            __fish_optware.build_path_for_dir $dir 
        end
    end
end

# Load cache from file
function __fish_optware.load_cache
    if [ -f $__fish_optware_path_file ]
        __fish_optware.conf.path_insert $__fish_optware_cache_bin
    else
        # Say something?
        return 1
    end
end

# Write cache to file
function __fish_optware.save_cache
    __fish_optware.build_cache > $__fish_optware_path_file
end

# Generate the link directory
function __fish_optware.generate_linkdir
    # create staging dir for new symlink repo
    set -l stg_dir "$__fish_optware_cache_bin.stg"
    set -l old_dir "$__fish_optware_cache_bin.old"

    mkdir -p $stg_dir

    for bin_dir in (cat $__fish_optware_path_file)
        if [ -e "$bin_dir/$__fish_optware_exports_name" ]
            # process manually specified executable names
            for ex in (cat "$bin_dir/$__fish_optware_exports_name")
                if [ -x "$bin_dir/$ex" ]
                    if not ln -s "$bin_dir/$ex" $stg_dir/
                        set_color red
                        echo "- while exporting $ex from $bin_dir"
                        set_color normal
                    end
                else
                    set_color red
                    echo "optware dir $bin_dir export $ex is not executable. skipping...."
                    set_color normal
                end
            end
        else
            # process automatically discovered executables
            for exe in (find $bin_dir -maxdepth 1 -type f -executable -not -iname '*.so')
                if not ln -s $exe $stg_dir/
                    set_color red
                    echo "- while exporting discovered executables from $bin_dir"
                    set_color normal
                end
            end
        end
    end

    test -e $old_dir; and rm -r $old_dir
    test -e $__fish_optware_cache_bin; and mv $__fish_optware_cache_bin $old_dir

    mv $stg_dir $__fish_optware_cache_bin
end

# User command
function optware -d 'fish optware helper'
    set directive help
    if set -q argv[1]
        set directive $argv[1]
        set -e argv[1]
    end

    switch $directive
        case rebuild
            if __fish_optware.save_cache and __fish_optware.generate_linkdir
                set_color green
                echo "Cache built"
            else
                set_color red
                echo "Failed to build cache"
            end
            set_color normal
        case search
            __fish_optware.build_cache
        case ignore-dir
            for dir in $argv
                if [ -d "$dir" -a ! -f "$dir/$__fish_optware_override_name" ]
                    touch $dir/$__fish_optware_override_name
                    echo "Empty override installed for $dir"
                else
                    echo "$dir already has a configuration file or an error ocurred"
                end
            end 
        case list
            set filter $argv[1]
            if [ -f $__fish_optware_path_file ]
                if [ -f "$dir/$__fish_optware_override_name" ]
                    echo "$dir has an override file containing"
                    for l in (cat $dir/$__fish_optware_override_name)
                        echo "  "$l
                    end
                    echo "  -end-"
                else if [ -z $argv ]
                    cat $__fish_optware_path_file
                else
                    grep -P $filter $__fish_optware_path_file
                end
            else
                echo "No cache file"
            end
        case \*
            echo "Commands: rebuild, search, list"
    end
end

# Install in to path
__fish_optware.load_cache
