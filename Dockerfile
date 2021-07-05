## Working clone form https://github.com/tpaviot/pythonocc-binderhub/blob/master/Dockerfile
## Recommended binderhub fails with segfault on visualization 

FROM jupyter/scipy-notebook:5cb007f03275
MAINTAINER Thomas Paviot <tpaviot@gmail.com>

USER root

ENV DEBIAN_FRONTEND=noninteractive

##############
# apt update #
##############
RUN apt-get update

RUN apt-get install -y wget git build-essential libgl1-mesa-dev libfreetype6-dev libglu1-mesa-dev libzmq3-dev libsqlite3-dev libicu-dev python3-dev libgl2ps-dev libfreeimage-dev libtbb-dev ninja-build bison autotools-dev automake libpcre3 libpcre3-dev tcl8.6 tcl8.6-dev tk8.6 tk8.6-dev libxmu-dev libxi-dev libopenblas-dev libboost-all-dev swig libxml2-dev cmake rapidjson-dev

RUN dpkg-reconfigure --frontend noninteractive tzdata

######################
# Python information #
######################
RUN which python
#RUN ls /opt/conda/include
#RUN ls /opt/conda/bin
#RUN ls /opt/conda/lib
RUN python -c 'import sys; print(sys.version_info[:])'

############################################################
# OCCT 7.5.1                                               #
# Download the official source package from git repository #
############################################################
WORKDIR /opt/build
RUN wget 'https://git.dev.opencascade.org/gitweb/?p=occt.git;a=snapshot;h=94c00556ea33f3895196b30c45b1fa901ad4c377;sf=tgz' -O occt-94c0055.tar.gz
RUN tar -zxvf occt-94c0055.tar.gz >> extracted_occt751_files.txt
RUN mkdir occt-94c0055/build
WORKDIR /opt/build/occt-94c0055/build

RUN ls /usr/include
RUN cmake -G Ninja \
 -DINSTALL_DIR=/opt/build/occt751 \
 -DBUILD_RELEASE_DISABLE_EXCEPTIONS=OFF \
 ..

RUN ninja install

RUN echo "/opt/build/occt751/lib" >> /etc/ld.so.conf.d/occt.conf
RUN ldconfig

RUN ls /opt/build/occt751
RUN ls /opt/build/occt751/lib

#############
# pythonocc #
#############
WORKDIR /opt/build
RUN git clone https://github.com/tpaviot/pythonocc-core
WORKDIR /opt/build/pythonocc-core
RUN git checkout 7.5.1
WORKDIR /opt/build/pythonocc-core/build

RUN cmake \
 -DOCE_INCLUDE_PATH=/opt/build/occt751/include/opencascade \
 -DOCE_LIB_PATH=/opt/build/occt751/lib \
 -DPYTHONOCC_BUILD_TYPE=Release \
 ..

RUN make -j3 && make install 

############
# svgwrite #
############
RUN pip install svgwrite

#######################
# Run pythonocc tests #
#######################
WORKDIR /opt/build/pythonocc-core/test
RUN python core_wrapper_features_unittest.py

##############################
# Install pythonocc examples #
##############################
WORKDIR /opt/build/
RUN git clone https://github.com/tpaviot/pythonocc-demos
WORKDIR /opt/build/pythonocc-demos
RUN cp -r /opt/build/pythonocc-demos/assets /home/jovyan/work
RUN cp -r /opt/build/pythonocc-demos/jupyter_notebooks /home/jovyan/work

#############
# pythreejs #
#############
WORKDIR /opt/build
RUN git clone https://github.com/jovyan/pythreejs
WORKDIR /opt/build/pythreejs
RUN git checkout 2.2.1
RUN chown -R jovyan .
USER jovyan
RUN /opt/conda/bin/pip install --user -e .
WORKDIR /opt/build/pythreejs/js
RUN npm run autogen
RUN npm run build:all
USER root
RUN jupyter nbextension install --py --symlink --sys-prefix pythreejs
RUN jupyter nbextension enable pythreejs --py --sys-prefix

########
# gmsh #
########
ENV CASROOT=/opt/build/occt751
WORKDIR /opt/build
RUN git clone https://gitlab.onelab.info/gmsh/gmsh
WORKDIR /opt/build/gmsh
RUN git checkout gmsh_4_6_0
WORKDIR /opt/build/gmsh/build

RUN cmake \
 -DCMAKE_BUilD_TYPE=Release \
 -DENABLE_OCC=ON \
 -DENABLE_OCC_CAF=ON \
 -DCMAKE_INSTALL_PREFIX=/usr/local \
 ..

RUN make -j9 && make install

################
# IfcOpenShell #
################
WORKDIR /opt/build
RUN git clone https://github.com/tpaviot/IfcOpenShell
WORKDIR /opt/build/IfcOpenShell
RUN git submodule update --init --remote --recursive
RUN git checkout v0.6.0
WORKDIR /opt/build/IfcOpenShell/build

RUN cmake \
 -DCOLLADA_SUPPORT=OFF \
 -DBUILD_EXAMPLES=OFF \
 -DOCC_INCLUDE_DIR=/opt/build/occt751/include/opencascade \
 -DOCC_LIBRARY_DIR=/opt/build/occt751/lib \
 -DLIBXML2_INCLUDE_DIR:PATH=/usr/include/libxml2 \
 -DLIBXML2_LIBRARIES=xml2 \
 -DPYTHON_LIBRARY=/opt/conda/lib/libpython3.8.so \
 -DPYTHON_INCLUDE_DIR=/opt/conda/include/python3.8 \
 -DPYTHON_EXECUTABLE=/opt/conda/bin/python \
 ../cmake

RUN make && make install

#####################
# back to user mode #
#####################
USER jovyan
WORKDIR /home/jovyan/work
