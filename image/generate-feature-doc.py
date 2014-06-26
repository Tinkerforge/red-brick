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
    make_root_fs_file_lines = file_handler.readlines()
    for index, line in enumerate(make_root_fs_file_lines):
        line = line.replace("\r", "")
        line = line.replace("\n", "")
        make_root_fs_file_lines[index] = line
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
        'python':{'process':True, 'name':'Python','packages':[],},
        'ruby':{'process':True, 'name':'Ruby','packages':[],},
        'shell':{'process':False, 'name':'Shell','packages':[],},
    }

    # Function for getting package list from file lines and with(out) tags
    # The lines can be delimited with single or double delimiters
    def get_packages_from_delimited_lines(lines, tag_start, tag_end, delimiters):
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
                fields_from_line = line.split(delimiters[0])
                package = [fields_from_line[0], fields_from_line[1], fields_from_line[2]]
                packages.append(package)
                continue
        return packages

    # Function for populating main_dict for a given package list and a language
    # The information for each package in package list is obtained from dpkg listing
    def populate_main_dict_from_dpkg_listing(package_list, key):
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
                        
    # Function for populating main_dict for a given set of lines and a language
    # The information for each package is obtained from the ready listing files
    def populate_main_dict_from_ready_listing(listing_file_ready_lines, listing_file_ready_common_lines, key):
        if len(listing_file_ready_lines) != 0:
            package_list = \
            get_packages_from_delimited_lines(listing_file_ready_lines, "", "", ["<==>"])
            for package in package_list:
                main_dict[key]["packages"].append(package)
        if len(listing_file_ready_common_lines) != 0:
            package_list= \
            get_packages_from_delimited_lines(listing_file_ready_common_lines, "", "", ["<==>"])
            for package in package_list:
                main_dict[key]["packages"].append(package)

    # Function for generalized processing for all the languages
    def common_processing(key, make_root_fs_file_delimiters):
        tag_start = "# GROUP-START:"+key
        tag_end = "# GROUP-END:"+key
        tag_start_config = "# GROUP-START-"+CONFIG_NAME+":"+key
        tag_end_config = "# GROUP-END-"+CONFIG_NAME+":"+key

        package_list = \
        get_packages_from_delimited_lines(multistrap_file_lines, tag_start, tag_end, ["=", " "])
        populate_main_dict_from_dpkg_listing(package_list, key)
        
        package_list = []
        
        if len(make_root_fs_file_delimiters) == 2:
            package_list_make_root_fs = \
            get_packages_from_delimited_lines\
            (make_root_fs_file_lines, tag_start, tag_end, \
            [make_root_fs_file_delimiters[0], make_root_fs_file_delimiters[1]])

            package_list_make_root_fs_config = \
            get_packages_from_delimited_lines\
            (make_root_fs_file_lines, tag_start_config, tag_end_config, \
            [make_root_fs_file_delimiters[0], make_root_fs_file_delimiters[1]])
            
            for package in package_list_make_root_fs:
                package_list.append(package)
            for package in package_list_make_root_fs_config:
                package_list.append(package)
        
        return package_list

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

            # Processing main_dict for C/C++
            if key == "c":
                common_processing(key, [])

            # Processing main_dict for Java
            elif key == "java":
                common_processing(key, [])
                populate_main_dict_from_ready_listing\
                (listing_file_ready_lines, listing_file_ready_common_lines, key)
            
            # Processing main_dict for Mono
            elif key == "mono":
                common_processing(key, [])
                populate_main_dict_from_ready_listing\
                (listing_file_ready_lines, listing_file_ready_common_lines, key)
            
            # Processing main_dict for Perl
            elif key == "perl":
                package_list = common_processing(key, ["cpanm install -n ", " "])
                for package in package_list:
                    for line in listing_file_lines:
                        name = line.split(" (")[0]
                        if name == package:
                            line_split_array = line.split(" - ")
                            name_version_array = line_split_array[0].split(" (")
                            main_dict_packages_entry = []
                            main_dict_packages_entry.append(package)
                            main_dict_packages_entry.append(name_version_array[1].replace(")", ""))
                            main_dict_packages_entry.append(line_split_array[1].strip())
                            main_dict[key]["packages"].append(main_dict_packages_entry)
                            break
            
            # Processing main_dict for PHP
            elif key == "php":
                package_list = common_processing(key, ["pear install --onlyreqdeps ", " "])
                for package in package_list:
                    for line in listing_file_lines:
                        line_split_array = line.split("<==>")
                        if line_split_array[0] == package:
                            main_dict_packages_entry = []
                            main_dict_packages_entry.append(package)
                            main_dict_packages_entry.append(line_split_array[2])
                            main_dict_packages_entry.append(line_split_array[3])
                            main_dict[key]["packages"].append(main_dict_packages_entry)
                            break
            
            # Processing main_dict for Python
            elif key == "python":
                package_list = common_processing(key, ["pip install ", " "])
                for package in package_list:
                    for line in listing_file_lines:
                        line_split_array = line.split("<==>")
                        if line_split_array[0] == package:
                            main_dict_packages_entry = []
                            main_dict_packages_entry.append(package)
                            main_dict_packages_entry.append(line_split_array[1])
                            main_dict_packages_entry.append(line_split_array[2])
                            main_dict[key]["packages"].append(main_dict_packages_entry)
                            break
            
            # Processing main_dict for Ruby
            elif key == "ruby":
                package_list = common_processing(key, ["gem install --no-ri --no-rdoc ", " "])
                for package in package_list:
                    for index, line in enumerate(listing_file_lines):
                        line_split_array = line.split(" (")
                        if len(line_split_array) == 2 and line_split_array[0] == package:
                            index += 1
                            while len(listing_file_lines[index]) > 1:
                                index += 1
                            index += 1
                            main_dict_packages_entry = []
                            main_dict_packages_entry.append(package)
                            main_dict_packages_entry.append(line_split_array[1].replace(")", ""))
                            main_dict_packages_entry.append(listing_file_lines[index].strip())
                            main_dict[key]["packages"].append(main_dict_packages_entry)
                            break
            else:
                print "Error: No proper key found for processing main_dict"
                exit(1)

    for key in main_dict:
        if not main_dict[key]["process"]:
            continue
        print (main_dict[key]["name"])
        print ""
        print(main_dict[key]["packages"])
        print("===================================")
