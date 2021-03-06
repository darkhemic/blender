#!/bin/sh

if [ "x$1" = "x--i-really-know-what-im-doing" ] ; then
  echo Proceeding as requested by command line ...
else
  echo "*** Please run again with --i-really-know-what-im-doing ..."
  exit 1
fi

repo="https://ceres-solver.googlesource.com/ceres-solver"
branch="master"
#tag="1.4.0"
tag=""
tmp=`mktemp -d`
checkout="$tmp/ceres"

GIT="git --git-dir $tmp/ceres/.git --work-tree $checkout"

git clone $repo $checkout

if [ $branch != "master" ]; then
    $GIT checkout -t remotes/origin/$branch
else
  if [ "x$tag" != "x" ]; then
      $GIT checkout $tag
  fi
fi

$GIT log -n 50 > ChangeLog

for p in `cat ./patches/series`; do
  echo "Applying patch $p..."
  cat ./patches/$p | patch -d $tmp/ceres -p1
done

find include -type f -not -iwholename '*.svn*' -exec rm -rf {} \;
find internal -type f -not -iwholename '*.svn*' -exec rm -rf {} \;

cat "files.txt" | while read f; do
  mkdir -p `dirname $f`
  cp $tmp/ceres/$f $f
done

rm -rf $tmp

sources=`find ./include ./internal -type f -iname '*.cc' -or -iname '*.cpp' -or -iname '*.c' | sed -r 's/^\.\//\t/' | \
  grep -v -E 'schur_eliminator_[0-9]_[0-9d]_[0-9d].cc' | \
  grep -v -E 'partitioned_matrix_view_[0-9]_[0-9d]_[0-9d].cc' | sort -d`
generated_sources=`find ./include ./internal -type f -iname '*.cc' -or -iname '*.cpp' -or -iname '*.c' | sed -r 's/^\.\//#\t\t/' | \
  grep -E 'schur_eliminator_[0-9]_[0-9d]_[0-9d].cc|partitioned_matrix_view_[0-9]_[0-9d]_[0-9d].cc' | sort -d`
headers=`find ./include ./internal -type f -iname '*.h' | sed -r 's/^\.\//\t/' | sort -d`

src_dir=`find ./internal -type f -iname '*.cc' -exec dirname {} \; -or -iname '*.cpp' -exec dirname {} \; -or -iname '*.c' -exec dirname {} \; | sed -r 's/^\.\//\t/' | sort -d | uniq`
src=""
for x in $src_dir $src_third_dir; do
  t=""

  if test  `echo "$x" | grep -c glog ` -eq 1; then
    continue;
  fi

  if test  `echo "$x" | grep -c generated` -eq 1; then
    continue;
  fi

  if stat $x/*.cpp > /dev/null 2>&1; then
    t="src += env.Glob('`echo $x'/*.cpp'`')"
  fi

  if stat $x/*.c > /dev/null 2>&1; then
    if [ -z "$t" ]; then
      t="src += env.Glob('`echo $x'/*.c'`')"
    else
      t="$t + env.Glob('`echo $x'/*.c'`')"
    fi
  fi

  if stat $x/*.cc > /dev/null 2>&1; then
    if [ -z "$t" ]; then
      t="src += env.Glob('`echo $x'/*.cc'`')"
    else
      t="$t + env.Glob('`echo $x'/*.cc'`')"
    fi
  fi

  if [ -z "$src" ]; then
    src=$t
  else
    src=`echo "$src\n$t"`
  fi
done

cat > CMakeLists.txt << EOF
# ***** BEGIN GPL LICENSE BLOCK *****
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# The Original Code is Copyright (C) 2012, Blender Foundation
# All rights reserved.
#
# Contributor(s): Blender Foundation,
#                 Sergey Sharybin
#
# ***** END GPL LICENSE BLOCK *****

# NOTE: This file is automatically generated by bundle.sh script
#       If you're doing changes in this file, please update template
#       in that script too

set(INC
	.
	include
	internal
	config
	../gflags
	../../
)

set(INC_SYS
	../../../Eigen3
)

set(SRC
${sources}

${headers}
)

#if(FALSE)
#	list(APPEND SRC
${generated_sources}
#	)
#endif()

if(WIN32)
	list(APPEND INC
		../glog/src/windows
	)

	if(NOT MINGW)
		list(APPEND INC
			../msinttypes
		)
	endif()
else()
	list(APPEND INC
		../glog/src
	)
endif()

add_definitions(
	-DCERES_HAVE_PTHREAD
	-DCERES_NO_SUITESPARSE
	-DCERES_NO_CXSPARSE
	-DCERES_NO_LAPACK
	-DCERES_RESTRICT_SCHUR_SPECIALIZATION
	-DCERES_HAVE_RWLOCK
)

if(WITH_OPENMP)
	add_definitions(
		-DCERES_USE_OPENMP
	)
endif()

TEST_UNORDERED_MAP_SUPPORT()
if(HAVE_STD_UNORDERED_MAP_HEADER)
	if(HAVE_UNORDERED_MAP_IN_STD_NAMESPACE)
		add_definitions(-DCERES_STD_UNORDERED_MAP)
	else()
		if(HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE)
			add_definitions(-DCERES_STD_UNORDERED_MAP_IN_TR1_NAMESPACE)
		else()
			add_definitions(-DCERES_NO_UNORDERED_MAP)
			message(STATUS "Replacing unordered_map/set with map/set (warning: slower!)")
		endif()
	endif()
else()
	if(HAVE_UNORDERED_MAP_IN_TR1_NAMESPACE)
		add_definitions(-DCERES_TR1_UNORDERED_MAP)
	else()
		add_definitions(-DCERES_NO_UNORDERED_MAP)
		message(STATUS "Replacing unordered_map/set with map/set (warning: slower!)")
	endif()
endif()

blender_add_lib(extern_ceres "\${SRC}" "\${INC}" "\${INC_SYS}")
EOF

cat > SConscript << EOF
#!/usr/bin/python

# NOTE: This file is automatically generated by bundle.sh script
#       If you're doing changes in this file, please update template
#       in that script too

import sys
import os

Import('env')

src = []
defs = []

$src
src += env.Glob('internal/ceres/generated/schur_eliminator_d_d_d.cc')
src += env.Glob('internal/ceres/generated/partitioned_matrix_view_d_d_d.cc')
#src += env.Glob('internal/ceres/generated/*.cc')

defs.append('CERES_HAVE_PTHREAD')
defs.append('CERES_NO_SUITESPARSE')
defs.append('CERES_NO_CXSPARSE')
defs.append('CERES_NO_LAPACK')
defs.append('CERES_RESTRICT_SCHUR_SPECIALIZATION')
defs.append('CERES_HAVE_RWLOCK')

if env['WITH_BF_OPENMP']:
    defs.append('CERES_USE_OPENMP')

if env['WITH_UNORDERED_MAP_SUPPORT']:
    if env['UNORDERED_MAP_HEADER'] == 'unordered_map':
        if env['UNORDERED_MAP_NAMESPACE'] == 'std':
            defs.append('CERES_STD_UNORDERED_MAP')
        elif env['UNORDERED_MAP_NAMESPACE'] == 'std::tr1':
            defs.append('CERES_STD_UNORDERED_MAP_IN_TR1_NAMESPACE')
    elif env['UNORDERED_MAP_NAMESPACE'] == 'std::tr1':
        defs.append('CERES_TR1_UNORDERED_MAP')
else:
    print("-- Replacing unordered_map/set with map/set (warning: slower!)")
    defs.append('CERES_NO_UNORDERED_MAP')

if not env['WITH_SHARED_PTR_SUPPORT']:
    print("-- Unable to find shared_ptr which is required for compilation.")
    exit(1)

if env['SHARED_PTR_HEADER'] == 'tr1/memory':
    defs.append('CERES_TR1_MEMORY_HEADER')
if env['SHARED_PTR_NAMESPACE'] == 'std::tr1':
    defs.append('CERES_TR1_SHARED_PTR')

incs = '. ../../ ../../../Eigen3 ./include ./internal ../gflags ./config'

# work around broken hashtable in 10.5 SDK
if env['OURPLATFORM'] == 'darwin' and env['WITH_BF_BOOST']:
    incs += ' ' + env['BF_BOOST_INC']
    defs.append('CERES_HASH_BOOST')

if env['OURPLATFORM'] in ('win32-vc', 'win32-mingw', 'linuxcross', 'win64-vc', 'win64-mingw'):
    if env['OURPLATFORM'] in ('win32-vc', 'win64-vc'):
        incs += ' ../msinttypes'

    incs += ' ../glog/src/windows'
else:
    incs += ' ../glog/src'

env.BlenderLib ( libname = 'extern_ceres', sources=src, includes=Split(incs), defines=defs, libtype=['extern', 'player'], priority=[20,137])
EOF
