!/bin/bash
# libpng : http://prdownloads.sourceforge.net/libpng/libpng-1.6.37.tar.xz

find . -name "FuncInfo.txt" -exec rm {} \;

FUZZER=${FUZZER:-ANGORA}

ANGORA_LOC="/home/cheong/Angora_func"
AFL_LOC="/home/cheong/afl-rb"

if [ ${FUZZER} = "ANGORA" ]; then
  FUZZER_LOC=${ANGORA_LOC}
else
  FUZZER_LOC=${AFL_LOC}
fi

rm  ${FUZZER_LOC}/subjects/readpng*
rm  ${FUZZER_LOC}/FInfos/FuncInfo-readpng*

mkdir ${FUZZER_LOC}/subjects
mkdir ${FUZZER_LOC}/FInfos

rm -rf install

if [ ! -d "zlib" ]
then
  wget https://www.zlib.net/zlib-1.2.11.tar.xz
  tar -xf zlib-1.2.11.tar.xz
  mv zlib-1.2.11 zlib
fi

cd zlib
rm -rf install
CC=gclang CXX=gclang++ ./configure --prefix=`pwd`/install --static
ZLIB_PATH=`pwd`/install
make clean
make -j 5
make install

cd ../

make distclean
CC=gclang CXX=gclang++ ./configure --prefix=`pwd`/install --disable-shared --with-zlib-prefix=${ZLIB_PATH}
make clean 
make -j 5
make install

gclang++ -std=c++11 contrib/oss-fuzz/libpng_read_fuzzer.cc -Icontrib/oss-fuzz -Iinstall/include/libpng16 \
  -Izlib/install/include -Linstall/lib -Lzlib/install/lib -lpng -lz  -o readpng
get-bc readpng

if [ ${FUZZER} = "ANGORA" ]; then
  ${FUZZER_LOC}/tools/gen_library_abilist.sh install/lib/libpng.a functional > png_abilist.txt
  ${ANGORA_LOC}/bin/angora-clang++ readpng.bc -L${ZLIB_PATH}/lib -Izlib/install/include -Linstall/lib -lpng -lz -o ${ANGORA_LOC}/subjects/readpng.fast
  mv FuncInfo.txt ${ANGORA_LOC}/FInfos/FuncInfo-readpng.txt
  ANGORA_TAINT_RULE_LIST=png_abilist.txt USE_TRACK=1 ${ANGORA_LOC}/bin/angora-clang++ readpng.bc -Izlib/install/include -L${ZLIB_PATH}/lib -Linstall/lib -lpng -lz -o ${ANGORA_LOC}/subjects/readpng.tt
else
  #didn't tested on afl
  ${FUZZER_LOC}/afl-clang-fast++ readpng.bc -o ${FUZZER_LOC}/subjects/readpng.afl
  mv FuncInfo.txt ${FUZZER_LOC}/FInfos/FuncInfo-readpng.txt
fi
