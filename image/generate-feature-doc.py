#!/usr/bin/env python
# -*- coding: utf-8 -*-

from os import path
from sys import argv

if __name__ == "__main__":
    if len(argv) != 2:
        print "\nError: Too many or too few parameters (provide image configuration name)\n"
        exit(1)

    # Configuration name
    CONFIG_NAME = argv[1]

    # Defining directories
    SCRIPT_RUN_DIR = path.dirname(path.abspath(__file__))
    BUILD_DIR = SCRIPT_RUN_DIR+"/build"
    CONFIG_DIR = SCRIPT_RUN_DIR+"/config"
    PATCHES_DIR = SCRIPT_RUN_DIR+"/patches"
    FEATURES_DIR = PATCHES_DIR+"/root-fs/"+CONFIG_NAME+"/tmp/features"
    FEATURES_DIR_COMMON = PATCHES_DIR+"/root-fs/common/tmp/features"

    # Checking the directory structure
    if not path.isdir(BUILD_DIR) or not path.isdir(CONFIG_DIR) \
       or not path.isdir(PATCHES_DIR) or not path.isdir(FEATURES_DIR) \
       or not path.isdir(FEATURES_DIR_COMMON):
        print "\nError: Wrong directory structure\n"
        exit(1)

    # Checking validity of configuration
    if not path.exists(CONFIG_DIR+"/root-fs/multistrap_"+CONFIG_NAME+".tmpl"):
        print "\nError: No such configuration\n"
        exit(1)

    # File locations
    MAKE_ROOT_FS_FILE = SCRIPT_RUN_DIR+"/make-root-fs.sh"
    DPKG_LISTING_FILE = BUILD_DIR+"/dpkg-"+CONFIG_NAME+".listing"
    MULTISTRAP_FILE = CONFIG_DIR+"/root-fs/multistrap_"+CONFIG_NAME+".tmpl"
    
    # Check for listing files
    if not path.exists(MAKE_ROOT_FS_FILE):
        print "\nError: No make-root-fs.sh file\n"
        exit(1)
    if not path.exists(DPKG_LISTING_FILE):
        print "\nError: No dpkg listing file\n"
        exit(1)
    if not path.exists(MULTISTRAP_FILE):
        print "\nError: No multistrap config file\n"
        exit(1)

    # Getting lines of make-root-fs.sh file
    file_handler = open(MAKE_ROOT_FS_FILE)
    make_root_fs_lines = file_handler.readlines()
    for index, line in enumerate(make_root_fs_lines):
        line = line.replace("\r", "")
        line = line.replace("\n", "")
        make_root_fs_lines[index] = line
    file_handler.close()

    # Getting lines of dpkg listing file
    file_handler = open(DPKG_LISTING_FILE)
    dpkg_listing_file_lines = file_handler.readlines()
    for index, line in enumerate(dpkg_listing_file_lines):
        line = line.replace("\r", "")
        line = line.replace("\n", "")
        dpkg_listing_file_lines[index] = line
    file_handler.close()
    
    # Getting lines of multistrap config file
    file_handler = open(MULTISTRAP_FILE)
    multistrap_file_lines = file_handler.readlines()
    for index, line in enumerate(multistrap_file_lines):
        line = line.replace("\r", "")
        line = line.replace("\n", "")
        multistrap_file_lines[index] = line
    file_handler.close()

    # The main dictionary
    main_dict = {
        'c':{'process':True, 'name':'C/C++','packages':[],},
        'delphi':{'process':False, 'name':'Delphi','packages':[],},
        'java':{'process':True, 'name':'Java','packages':[],},
        'javascript':{'process':False, 'name':'JavaScript','packages':[],},
        'labview':{'process':False, 'name':'LabVIEW','packages':[],},
        'mathematica':{'process':False, 'name':'Mathematica','packages':[],},
        'matlab':{'process':False, 'name':'MATLAB/Octave','packages':[],},
        'mono':{'process':True, 'name':'Mono','packages':[],},
        'perl':{'process':True, 'name':'Perl','packages':[],},
        'php':{'process':True, 'name':'PHP','packages':[],},
        'python':{'process':False, 'name':'Python','packages':[],},
        'ruby':{'process':True, 'name':'Ruby','packages':[],},
        'shell':{'process':False, 'name':'Shell','packages':[],},
    }

    # Function for getting package list from file lines and with(out) tags.
    # Files like, multistap config files, make-root-fs.sh file etc.
    def get_packages_as_list(lines, tag_start, tag_end, delimiters):
        tag_start_found = False
        packages = []
        for line in lines:
            if tag_start and tag_end:
                if tag_start_found:
                    if line == tag_end:
                        tag_start_found = False
                        continue
                    else:
                        line_split_array = line.split(delimiters[0])
                        packages_from_line = line_split_array[1].split(delimiters[1])
                        for package in packages_from_line:
                            packages.append(package)
                        continue
                if line == tag_start:
                    tag_start_found = True
                    continue
            if not tag_start and not tag_end:
                packages_from_line = line.split(delimiters[0])
                for package in packages_from_line:
                    packages.append(package)
                continue
        return packages

    # Populating installed packages for each language with details
    for key in main_dict:
        if main_dict[key]["process"]:
            listing_file = BUILD_DIR+"/"+key+"-"+CONFIG_NAME+".listing"
            listing_file_ready = FEATURES_DIR+"/"+key+"_features/"+key+".listing"
            listing_file_ready_common = FEATURES_DIR_COMMON+"/"+key+"_features/"+key+".listing"
        
            if not path.exists(DPKG_LISTING_FILE) \
               and not path.exists(listing_file) \
               and not path.exists(listing_file_ready) \
               and not path.exists(listing_file_ready_common):
                print ("Error: No listing files found for langauge: "+main_dict[key]["name"])
                exit(1)

            if path.exists(listing_file):
                file_handler = open(listing_file)
                listing_file_lines = file_handler.readlines()
                file_handler.close()
                for index, line in enumerate(listing_file_lines):
                    line = line.replace("\r", "")
                    line = line.replace("\n", "")
                    listing_file_lines[index] = line
            else:
                listing_file_lines = []

            if path.exists(listing_file_ready):
                file_handler = open(listing_file_ready)
                listing_file_ready_lines = file_handler.readlines()
                file_handler.close()
                for index, line in enumerate(listing_file_ready_lines):
                    line = line.replace("\r", "")
                    line = line.replace("\n", "")
                    listing_file_ready_lines[index] = line
            else:
                listing_file_ready_lines = []
                
            if path.exists(listing_file_ready_common):
                file_handler = open(listing_file_ready_common)
                listing_file_ready_common_lines = file_handler.readlines()
                file_handler.close()
                for index, line in enumerate(listing_file_ready_common_lines):
                    line = line.replace("\r", "")
                    line = line.replace("\n", "")
                    listing_file_ready_common_lines[index] = line
            else:
                listing_file_ready_common_lines = []

            if key == "c":
                tag_start = "# GROUP-START:"+key
                tag_end = "# GROUP-END:"+key
                package_list = get_packages_as_list(multistrap_file_lines, tag_start, tag_end, ("="," "))
                for package in package_list:
                    for line in dpkg_listing_file_lines:
                        line_split_array = line.split("<==>")
                        if len(line_split_array) == 3:
                            if line_split_array[0] == package:
                                main_dict_packages_entry = []
                                main_dict_packages_entry.append(line_split_array[0])
                                main_dict_packages_entry.append(line_split_array[1])
                                main_dict_packages_entry.append(line_split_array[2])
                                main_dict[key]["packages"].append(main_dict_packages_entry)
                                break
            elif key == "delphi":
                print("")
            elif key == "java":
                print("")
            elif key == "javascript":
                print("")
            elif key == "labview":
                print("")
            elif key == "mathematica":
                print("")
            elif key == "matlab":
                print("")
            elif key == "mono":
                print("")
            elif key == "perl":
                print("")
            elif key == "php":
                print("")
            elif key == "python":
                print("")
            elif key == "ruby":
                print("")
            elif key == "shell":
                print("")
            else:
                print "Error: No proper key found for processing main_dict"
                exit(1)

    print(main_dict)


