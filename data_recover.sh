#!/bin/bash

# make loop device, find largest partition
# if mountable, mount read-only and grab data 
# use photorec on it (free space only if it was mountable)
# if was mountable, delete dups from photorec recovery using dup

# just remove small garbage binary files
find file* recup_dir.* -type f -size -1k -exec grep -IL | ls -lh "{}" \;

# run dup for identical files

# safety
exit 0

# maybe at some point we can use imgdiff.sh

# sort by size
cnt=0;
dup --no-prog -p -tsum=0 -tsize=100 -tbyte=0 $@ 2>&1 | while read line ; do
	if [[ "${line:0:1}" == "@" ]] ; then
		(( ++cnt ))
		mkdir "./size_$cnt" 2>/dev/null
		line="`echo $line | cut -d' ' -f2`" # remove the @ from the line
	fi
	if (( $cnt > 0 )) ; then
		echo "mv -n \"$line\" ./size_$cnt"
		mv -n "$line" "./size_$cnt/"
	fi
done

# sort by sum
for file in ./size_* ; do
	cnt=0;
	dup --no-prog -p -tsum=100 -size=100 -tbyte=0 $@ 2>&1 | while read line ; do
		if [[ "${line:0:1}" == "@" ]] ; then
			(( ++cnt ))
			mkdir "./$file/$sum_$cnt" 2>/dev/null
			line="`echo $line | cut -d' ' -f2`" # remove the @ from the line
		fi
		if (( $cnt > 0 )) ; then
			echo "mv -n \"$line\" ./$file/sum_$cnt"
			mv -n "$file" "./$file/sum_$cnt"
		fi
	done
done
