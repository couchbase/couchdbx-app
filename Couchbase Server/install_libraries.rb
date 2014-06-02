#! /usr/bin/env ruby
#
# This script makes the Couchbase Server binaries self-contained by locating all nonstandard
# external dynamic library dependencies, copying those libraries into "lib/", and fixing up the
# imports to point to the copied libraries.
#
# It must be called with the cwd set to the root directory of the installation ("couchbase-core").


require "pathname"

LibraryDir = Pathname.new("lib")
BinDir = Pathname.new("bin")

def log (message)
  #   puts message       # Uncomment for verbose logging
end

# Returns the libraries imported by the binary at 'path', as an array of Pathnames.
def get_imports (path)
  imports = []
  puts "path: #{path}"
  for line in `otool -L '#{path}'`.split("\n")
    if line =~ /^\t(.*)\s*\(.*\)$/
      import = Pathname.new($1.rstrip)
      if import.basename != path.basename
        imports << import
      end
    end
  end
  return imports
end


# Edits the binary at 'libpath' to change its import of 'import' to 'newimport'.
def change_import (libpath, import, newimport)
  log "\tchange_import called with libpath: #{libpath}, import: #{import}, newimport: #{newimport}"
  return  if newimport == import
  log "\tChange import #{import} to #{newimport}"
  unless system("install_name_tool", "-change", import, newimport, libpath)
    fail "install_name_tool failed"
  end
end


# Copies a library from 'src' into 'lib/', and recursively processes its imports.
def copy_lib (src, loaded_from)
  return src  if src.to_s.start_with?("lib/")

  dst = LibraryDir + src.basename
  if dst.exist?  # already been copied
    return dst
  end

  if src.dirname.to_s == "@loader_path"
    src = loaded_from.dirname + src.basename
  end
  fail "bad path #{src}"  unless src.absolute?

  log "\tCopying #{src} --> #{dst}"
  unless system("cp", src.to_s, dst.to_s)
    fail "cp failed on #{src}"
  end
  dst.chmod(0644)  # Make it writable so we can change its imports

  process(dst, src)
  return dst
end


# Fixes up the binary at 'file' by locating external library dependencies and copying those
# libraries to "lib/".
# If 'original_path' is given, it is the path from which 'file' was copied; this is needed
# for resolution of '@loader_path'-relative imports.
def process (file, original_path =nil)
  log "-- #{file} ..."
  for import in get_imports(file) do
    path = import.to_s
    unless path.start_with?("/usr/lib/") || path.start_with?("/System/")
      dst = copy_lib(import, (original_path || file))
      unless dst.absolute?
        dst = '@loader_path/' + dst.relative_path_from(file.dirname).to_s
      end
      change_import(file.to_s, import.to_s, dst.to_s)
    end
  end
  log "\tend #{file}"
end


# Calls process() on every dylib in the directory tree rooted at 'dir'.
def process_libs_in_tree (dir)
  dir.children.each do |file|
    if file.directory?
      process_libs_in_tree file
    elsif (file.extname == ".dylib" || file.extname == ".so") && file.ftype == "file"
      process(file)
    end
  end
end
  
def process_binaries_in_tree (dir)
  dir.children.each do |file|
    if file.directory?
      process_binaries_in_tree file
    elsif file.ftype == "file" && file.executable?
      File.open(file, 'r') do |f|
        if f.getc == '#' && f.getc == '!'
          log "Skipping script file #{file}."
        else
          process(file)
        end
      end
    else
      log "Skipping #{file}."
    end
  end
end


### OK, here's the main code:

puts "Fixing library imports in #{BinDir} ..."
process_binaries_in_tree BinDir

puts "\nFixing library imports in #{LibraryDir} ..."
process_libs_in_tree LibraryDir

puts "\nDone fixing library imports!"
