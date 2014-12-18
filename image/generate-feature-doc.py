#!/usr/bin/env python
# -*- coding: utf-8 -*-

from os import path
from os import listdir
from sys import argv
from subprocess import call
import json

if __name__ == "__main__":
    # Defining directories
    SCRIPT_RUN_DIR = path.dirname(path.abspath(__file__))
    BUILD_DIR = SCRIPT_RUN_DIR+"/build"
    CONFIG_DIR = SCRIPT_RUN_DIR+"/config"
    PATCHES_DIR = SCRIPT_RUN_DIR+"/patches"
    FEATURES_DIR_COMMON = PATCHES_DIR+"/root-fs/common/tmp/features"
    OUTPUT_DIR = BUILD_DIR+"/feature_tables"
    ETC_VERSION_PATH = PATCHES_DIR+"/root-fs/common/etc/tf_installed_versions"

    # Checking the directory structure
    if not path.isdir(BUILD_DIR) or not path.isdir(CONFIG_DIR) \
       or not path.isdir(PATCHES_DIR) or not path.isdir(FEATURES_DIR_COMMON) \
       or not path.isdir(CONFIG_DIR+"/root-fs"):
        print "\nError: Wrong directory structure\n"
        exit(1)
    
    if len(argv) == 2 and (argv[1] in ('full', 'fast')):
        CONFIG_LIST = [argv[1]]
    else:
        # Getting available configurations
        CONFIG_LIST = []
        for file_name in listdir(CONFIG_DIR+"/root-fs"):
            file_name_split_array_us = file_name.split("_")
            file_name_split_array_dot = file_name_split_array_us[1].split(".")
            CONFIG_LIST.append(file_name_split_array_dot[0])
        if len(CONFIG_LIST) == 0:
            print "\nError: No valid image configurations available\n"
            exit(1)

    # Check for multistrap files
    MULTISTRAP_FILES_DICT = {}
    for config in CONFIG_LIST:
        if not path.exists(CONFIG_DIR+"/root-fs/multistrap_"+config+".tmpl"):
            print "\nError: multistrap config file missing: "+config+"\n"
            exit(1)
        else:
            MULTISTRAP_FILES_DICT[config] = {"path":CONFIG_DIR+"/root-fs/multistrap_"+config+".tmpl"}
    
    for config in MULTISTRAP_FILES_DICT:
        file_handler = open(MULTISTRAP_FILES_DICT[config]["path"])
        if file_handler:
            multistrap_file_lines = file_handler.readlines()
            file_handler.close()
            MULTISTRAP_FILES_DICT[config]["lines"] = []
            for line in multistrap_file_lines:
                if line[:1] == "#":
                    if line.strip()[:14] == "# GROUP-START:" \
                    or line.strip()[:12] == "# GROUP-END:":
                        line = line.replace("\r", "")
                        line = line.replace("\n", "")
                        line = line.strip()
                        MULTISTRAP_FILES_DICT[config]["lines"].append(line)
                    else:
                        
                        continue
                else:
                    line = line.replace("\r", "")
                    line = line.replace("\n", "")
                    line = line.strip()
                    MULTISTRAP_FILES_DICT[config]["lines"].append(line)

    # Check for make-root-fs.sh file
    MAKE_ROOT_FS_FILE = SCRIPT_RUN_DIR+"/make-root-fs.sh"
    if not path.exists(MAKE_ROOT_FS_FILE):
        print "\nError: make-root-fs.sh file missing\n"
        exit(1)
    else:
        file_handler = open(MAKE_ROOT_FS_FILE)
        if file_handler:
            MAKE_ROOT_FS_FILE_LINES = file_handler.readlines()
            file_handler.close()
            for i, line in enumerate(MAKE_ROOT_FS_FILE_LINES):
                if line[:1] == "#":
                    if line.strip()[:14] == "# GROUP-START:" \
                    or line.strip()[:12] == "# GROUP-END:":
                        line = line.replace("\r", "")
                        line = line.replace("\n", "")
                        line = line.strip()
                        MAKE_ROOT_FS_FILE_LINES[i] = line
                    else:
                        continue
                else:
                    line = line.replace("\r", "")
                    line = line.replace("\n", "")
                    line = line.strip()
                    MAKE_ROOT_FS_FILE_LINES[i] = line

    # Cleaning up
    print "\nInfo: Cleaning up\n"
    call(["rm -rf "+OUTPUT_DIR], shell=True)
    call(["mkdir "+OUTPUT_DIR], shell=True)

    # The main dictionary
    MAIN_DICT = {
        "c":{"process":True, "name":"C/C++","packages":[],},
        "delphi":{"process":False, "name":"Delphi","packages":[],},
        "java":{"process":True, "name":"Java","packages":[],},
        "node":{"process":False, "name":"Node.js","packages":[],},
        #"labview":{"process":False, "name":"LabVIEW","packages":[],},
        #"mathematica":{"process":False, "name":"Mathematica","packages":[],},
        "matlab":{"process":False, "name":"MATLAB/Octave","packages":[],},
        "mono":{"process":True, "name":"Mono","packages":[],},
        "perl":{"process":True, "name":"Perl","packages":[],},
        "php":{"process":True, "name":"PHP","packages":[],},
        "python":{"process":True, "name":"Python","packages":[],},
        "ruby":{"process":True, "name":"Ruby","packages":[],},
        #"shell":{"process":False, "name":"Shell","packages":[],},
    }
    
    # Define the columns
    COLUMNS = ["Name", "Version", "Description", {}]
    
    # Storing available configs in columns
    for i, config in enumerate(sorted(CONFIG_LIST)):
        COLUMNS[len(COLUMNS)-1][config] = i

    # Check for dpkg listing files
    DPKG_LISTING_FILES_DICT = {}
    for config in CONFIG_LIST:
        if not path.exists(BUILD_DIR+"/dpkg-"+config+".listing"):
            print "\nError: dpkg listing file missing\n"
            exit(1)
        else:
            DPKG_LISTING_FILES_DICT[config] = {"path":BUILD_DIR+"/dpkg-"+config+".listing"}
    
    for config in DPKG_LISTING_FILES_DICT:
        file_handler = open(DPKG_LISTING_FILES_DICT[config]["path"])
        if file_handler:
            dpkg_listing_file_lines = file_handler.readlines()
            file_handler.close()
            DPKG_LISTING_FILES_DICT[config]["lines"] = []
            for line in dpkg_listing_file_lines:
                line = line.replace("\r", "")
                line = line.replace("\n", "")
                line = line.strip()
                DPKG_LISTING_FILES_DICT[config]["lines"].append(line)

    # Check for language listing files
    LISTING_FILES_DICT = {}
    for language in MAIN_DICT:
        if MAIN_DICT[language]["process"]:
            LISTING_FILES_DICT[language] = {}
    
    for language in MAIN_DICT:
        if MAIN_DICT[language]["process"]:
            for config in CONFIG_LIST:
                if not path.exists(DPKG_LISTING_FILES_DICT[config]["path"]) \
                and not path.exists(BUILD_DIR+"/"+language+"-"+config+".listing") \
                and not path.exists(FEATURES_DIR_COMMON+"/"+language+"_features/"+language+".listing") \
                and not path.exists\
                (PATCHES_DIR+"/root-fs/"+config+"/tmp/features/"+language+"_features/"+language+".listing"):
                    print "\nError: Listing file missing: "+language+"\n"
                    exit(1)
                else:
                    LISTING_FILES_DICT[language][config] = {
                    "listing_file_path":"",
                    "listing_file_lines":[],
                    "listing_file_ready_path":"",
                    "listing_file_ready_lines":[],
                    "listing_file_ready_common_path":"",
                    "listing_file_ready_common_lines":[],
                    }
                    
                    if path.exists(BUILD_DIR+"/"+language+"-"+config+".listing"):
                        file_handler = open(BUILD_DIR+"/"+language+"-"+config+".listing")
                        if file_handler:
                            LISTING_FILES_DICT[language][config]["listing_file_path"] = \
                            BUILD_DIR+"/"+language+"-"+config+".listing"
                            listing_file_lines = file_handler.readlines()
                            file_handler.close()
                            LISTING_FILES_DICT[language][config]["listing_file_lines"] = []
                            for line in listing_file_lines:
                                line = line.replace("\r", "")
                                line = line.replace("\n", "")
                                line = line.strip()
                                LISTING_FILES_DICT[language][config]["listing_file_lines"].append(line)

                    if path.exists\
                    (PATCHES_DIR+"/root-fs/"+config+"/tmp/features/"+language+"_features/"+language+".listing"):
                        file_handler = \
                        open(PATCHES_DIR+"/root-fs/"+config+"/tmp/features/"+language+"_features/"+language+".listing")
                        if file_handler:
                            LISTING_FILES_DICT[language][config]["listing_file_ready_path"] = \
                            PATCHES_DIR+"/root-fs/"+config+"/tmp/features/"+language+"_features/"+language+".listing"
                            listing_file_ready_lines = file_handler.readlines()
                            file_handler.close()
                            LISTING_FILES_DICT[language][config]["listing_file_ready_lines"] = []
                            for line in listing_file_ready_lines:
                                line = line.replace("\r", "")
                                line = line.replace("\n", "")
                                line = line.strip()
                                LISTING_FILES_DICT[language][config]["listing_file_ready_lines"].append(line)
                        
                    if path.exists(FEATURES_DIR_COMMON+"/"+language+"_features/"+language+".listing"):
                        file_handler = open(FEATURES_DIR_COMMON+"/"+language+"_features/"+language+".listing")
                        if file_handler:
                            LISTING_FILES_DICT[language][config]["listing_file_ready_common_path"] = \
                            FEATURES_DIR_COMMON+"/"+language+"/"+language+".listing"
                            listing_file_ready_common_lines = file_handler.readlines()
                            file_handler.close()
                            LISTING_FILES_DICT[language][config]["listing_file_ready_common_lines"] = []
                            for line in listing_file_ready_common_lines:
                                line = line.replace("\r", "")
                                line = line.replace("\n", "")
                                line = line.strip()
                                LISTING_FILES_DICT[language][config]["listing_file_ready_common_lines"].append(line)

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

    # Function for populating MAIN_DICT for a given package list and a language
    # The information for each package in package list is obtained from dpkg listing
    def populate_main_dict_from_dpkg_listing(language, config, package_list):
        for package in package_list:
            for line in DPKG_LISTING_FILES_DICT[config]["lines"]:
                line_split_array = line.split("<==>")
                if len(line_split_array) == 3:
                    if line_split_array[0] == package:
                        package_name = line_split_array[0]
                        package_version = line_split_array[1]
                        package_description = line_split_array[2]
                        found_index = -1
                        for i, package in enumerate(MAIN_DICT[language]["packages"]):
                            if package[0] == package_name \
                            and package[1] == package_version:
                                found_index = i
                                break
                        if found_index > -1:
                            MAIN_DICT[language]["packages"][found_index][3][config] = True
                            continue
                        else:
                            main_dict_packages_entry = []
                            main_dict_packages_entry.append(package_name)
                            main_dict_packages_entry.append(package_version)
                            main_dict_packages_entry.append(package_description)
                            main_dict_packages_entry.append({config:True})
                            MAIN_DICT[language]["packages"].append(main_dict_packages_entry)
                        
    # Function for populating MAIN_DICT for a given set of lines and a language
    # The information for each package is obtained from the ready listing files
    def populate_main_dict_from_ready_listing(language, config):
        if len(LISTING_FILES_DICT[language][config]["listing_file_ready_lines"]) != 0:
            listing_file_ready_lines = LISTING_FILES_DICT[language][config]["listing_file_ready_lines"]
            package_list = \
            get_packages_from_delimited_lines(listing_file_ready_lines, "", "", ["<==>"])
            for package in package_list:
                package_name = package[0]
                package_version = package[1]
                package_description = package[2]
                found_index = -1
                for i, package in enumerate(MAIN_DICT[language]["packages"]):
                    if package[0] == package_name \
                    and package[1] == package_version:
                        found_index = i
                        break
                if found_index > -1:
                    MAIN_DICT[language]["packages"][found_index][3][config] = True
                    continue
                else:
                    main_dict_packages_entry = []
                    main_dict_packages_entry.append(package_name)
                    main_dict_packages_entry.append(package_version)
                    main_dict_packages_entry.append(package_description)
                    main_dict_packages_entry.append({config:True})
                    MAIN_DICT[language]["packages"].append(main_dict_packages_entry)
    
        if len(LISTING_FILES_DICT[language][config]["listing_file_ready_common_lines"]) != 0:
            listing_file_ready_common_lines = \
            LISTING_FILES_DICT[language][config]["listing_file_ready_common_lines"]
            package_list = \
            get_packages_from_delimited_lines(listing_file_ready_common_lines, "", "", ["<==>"])
            for package in package_list:
                package_name = package[0]
                package_version = package[1]
                package_description = package[2]
                found_index = -1
                for i, package in enumerate(MAIN_DICT[language]["packages"]):
                    if package[0] == package_name \
                    and package[1] == package_version:
                        found_index = i
                        break
                if found_index > -1:
                    MAIN_DICT[language]["packages"][found_index][3][config] = True
                    continue
                else:
                    main_dict_packages_entry = []
                    main_dict_packages_entry.append(package_name)
                    main_dict_packages_entry.append(package_version)
                    main_dict_packages_entry.append(package_description)
                    main_dict_packages_entry.append({config:True})
                    MAIN_DICT[language]["packages"].append(main_dict_packages_entry)

    # Function for generalized processing for all the languages
    def common_processing(language, config, make_root_fs_file_delimiters):
        tag_start = "# GROUP-START:"+language
        tag_end = "# GROUP-END:"+language
        tag_start_config = "# GROUP-START-"+config+":"+language
        tag_end_config = "# GROUP-END-"+config+":"+language

        package_list = \
        get_packages_from_delimited_lines\
        (MULTISTRAP_FILES_DICT[config]["lines"], tag_start, tag_end, ["=", " "])
        populate_main_dict_from_dpkg_listing(language, config, package_list)
        
        if len(make_root_fs_file_delimiters) == 2:
            package_list = []
            
            package_list_make_root_fs = \
            get_packages_from_delimited_lines\
            (MAKE_ROOT_FS_FILE_LINES, tag_start, tag_end, \
            [make_root_fs_file_delimiters[0], make_root_fs_file_delimiters[1]])

            package_list_make_root_fs_config = \
            get_packages_from_delimited_lines\
            (MAKE_ROOT_FS_FILE_LINES, tag_start_config, tag_end_config, \
            [make_root_fs_file_delimiters[0], make_root_fs_file_delimiters[1]])
            
            for package in package_list_make_root_fs:
                package_list.append(package)
            for package in package_list_make_root_fs_config:
                package_list.append(package)
        
        return package_list



    # Populating installed packages for each language with details
    for language in MAIN_DICT:
        if MAIN_DICT[language]["process"]:
            for config in CONFIG_LIST:
                # Processing MAIN_DICT for C/C++
                if language == "c":
                    common_processing(language, config, [])

                # Processing MAIN_DICT for Java
                elif language == "java":
                    common_processing(language, config, [])
                    populate_main_dict_from_ready_listing(language, config)
            
                # Processing MAIN_DICT for Mono
                elif language == "mono":
                    common_processing(language, config, [])
                    populate_main_dict_from_ready_listing(language, config)
                
                # Processing MAIN_DICT for Perl
                elif language == "perl":
                    package_list = common_processing(language, config, ["cpanm install -n ", " "])
                    for package in package_list:
                        for line in LISTING_FILES_DICT[language][config]["listing_file_lines"]:
                            package_name = line.split(" (")[0]
                            if package_name == package:
                                line_split_array = line.split(" - ")
                                name_version_array = line_split_array[0].split(" (")
                                package_version = name_version_array[1].replace(")", "")
                                package_description = line_split_array[1].strip()
                                found_index = -1
                                for i, package in enumerate(MAIN_DICT[language]["packages"]):
                                    if package[0] == package_name \
                                    and package[1] == package_version:
                                        found_index = i
                                        break
                                if found_index > -1:
                                    MAIN_DICT[language]["packages"][found_index][3][config] = True
                                    continue
                                else:
                                    main_dict_packages_entry = []
                                    main_dict_packages_entry.append(package_name)
                                    main_dict_packages_entry.append(package_version)
                                    main_dict_packages_entry.append(package_description)
                                    main_dict_packages_entry.append({config:True})
                                    MAIN_DICT[language]["packages"].append(main_dict_packages_entry)

                # Processing MAIN_DICT for PHP
                elif language == "php":
                    package_list = common_processing(language, config, ["pear install --onlyreqdeps ", " "])
                    for package in package_list:
                        for line in LISTING_FILES_DICT[language][config]["listing_file_lines"]:
                            line_split_array = line.split("<==>")
                            if line_split_array[0] == package:
                                package_name = line_split_array[0]
                                package_version = line_split_array[2]
                                package_description = line_split_array[3]
                                found_index = -1
                                for i, package in enumerate(MAIN_DICT[language]["packages"]):
                                    if package[0] == package_name \
                                    and package[1] == package_version:
                                        found_index = i
                                        break
                                if found_index > -1:
                                    MAIN_DICT[language]["packages"][found_index][3][config] = True
                                    continue
                                else:
                                    main_dict_packages_entry = []
                                    main_dict_packages_entry.append(package_name)
                                    main_dict_packages_entry.append(package_version)
                                    main_dict_packages_entry.append(package_description)
                                    main_dict_packages_entry.append({config:True})
                                    MAIN_DICT[language]["packages"].append(main_dict_packages_entry)
                                    
                # Processing MAIN_DICT for Python
                elif language == "python":
                    package_list = common_processing(language, config, ["pip install ", " "])
                    for package in package_list:
                        for line in LISTING_FILES_DICT[language][config]["listing_file_lines"]:
                            line_split_array = line.split("<==>")
                            if line_split_array[0] == package:
                                package_name = line_split_array[0]
                                package_version = line_split_array[1]
                                package_description = line_split_array[2]
                                found_index = -1
                                for i, package in enumerate(MAIN_DICT[language]["packages"]):
                                    if package[0] == package_name \
                                    and package[1] == package_version:
                                        found_index = i
                                        break
                                if found_index > -1:
                                    MAIN_DICT[language]["packages"][found_index][3][config] = True
                                    continue
                                else:
                                    main_dict_packages_entry = []
                                    main_dict_packages_entry.append(package_name)
                                    main_dict_packages_entry.append(package_version)
                                    main_dict_packages_entry.append(package_description)
                                    main_dict_packages_entry.append({config:True})
                                    MAIN_DICT[language]["packages"].append(main_dict_packages_entry)
            
                # Processing MAIN_DICT for Ruby
                elif language == "ruby":
                    package_list = common_processing(language, config, ["gem install --no-ri --no-rdoc ", " "])
                    for package in package_list:
                        listing_file_lines = LISTING_FILES_DICT[language][config]["listing_file_lines"]
                        for i, line in enumerate(listing_file_lines):
                            line_split_array = line.split(" (")
                            if len(line_split_array) == 2 and line_split_array[0] == package:
                                package_name = line_split_array[0]
                                package_version = line_split_array[1].replace(")", "")
                                i += 1
                                while len(listing_file_lines[i]) > 1:
                                    i += 1
                                i += 1
                            
                                package_description = ""
                                package_description += listing_file_lines[i].strip()
                            
                                while len(listing_file_lines[i+1]) > 1:
                                    package_description += " "
                                    package_description += listing_file_lines[i+1].strip()
                                    i += 1

                                found_index = -1
                                for j, package in enumerate(MAIN_DICT[language]["packages"]):
                                    if package[0] == package_name \
                                    and package[1] == package_version:
                                        found_index = j
                                        break
                                if found_index > -1:
                                    MAIN_DICT[language]["packages"][found_index][3][config] = True
                                    continue
                                else:
                                    main_dict_packages_entry = []
                                    main_dict_packages_entry.append(package_name)
                                    main_dict_packages_entry.append(package_version)
                                    main_dict_packages_entry.append(package_description)
                                    main_dict_packages_entry.append({config:True})
                                    MAIN_DICT[language]["packages"].append(main_dict_packages_entry)
                
                else:
                    print "\nError: No proper key found for processing MAIN_DICT\n"
                    exit(1)

    # Write dict as json file to file system, Brick Viewer reads this in versions tab
    with open(ETC_VERSION_PATH, "w") as f:
        f.write(json.dumps(MAIN_DICT))

    # Generating the output files language wise
    for language in sorted(MAIN_DICT):
        if MAIN_DICT[language]["process"]:
            checkmark = "|c|"
            column_widths = []
            max_column_widths = []
            config_column_widths = []
            
            # Getting all the elements except the last one
            for coloumn in COLUMNS[:-1]:
                column_widths.append([])

            for package in MAIN_DICT[language]["packages"]:
                # Getting all the elements except the last one
                for i, field in enumerate(package[:-1]):
                    column_widths[i].append(len(field))
            
            for column_width_list in column_widths:
                max_column_widths.append(max(column_width_list))
            
            for i, column_width in enumerate(max_column_widths):
                if column_width < len(COLUMNS[i]):
                    max_column_widths[i] = len(COLUMNS[i])
            
            # Getting maximum config column width
            for config_column in COLUMNS[-1]:
                config_column_widths.append(len(config_column))
            max_config_column_width = max(config_column_widths)
            if max_config_column_width < len(checkmark):
                max_config_column_width = len(checkmark)
            
            # Generating language underline
            language_underline = ""
            for i in range (0, len(MAIN_DICT[language]["name"])):
                language_underline += "-"

            # Generating table border
            table_border = ""
            for max_column_width in max_column_widths:
                for i in range(0, max_column_width):
                    table_border += "="
                table_border += " "
                
            for i in range(0, len(CONFIG_LIST)):
                for j in range(0, max_config_column_width):
                    table_border += "="
                if i != len(CONFIG_LIST) - 1:
                    table_border += " "
            
           # Generating table column headers
            table_column_header_line = ""
            
            # Getting all the elements except the last one
            for i, column_header in enumerate(COLUMNS[:-1]):
                table_column_header_line += column_header
                for j in range(0, (max_column_widths[i] - len(column_header)) + 1):
                    table_column_header_line += " "

            for i, config_column in enumerate(sorted(COLUMNS[-1])):
                table_column_header_line += config_column
                if i == len(COLUMNS[-1]) - 1:
                    break
                else:
                    for i in range(0, (max_config_column_width - len(config_column)) + 1):
                        table_column_header_line += " "
            
            #Generating table rows
            table_rows = ""
            
            for i, package in enumerate(sorted(MAIN_DICT[language]["packages"])):
                # Getting all the elements except the last one
                for j, field in enumerate(package[:-1]):
                    table_rows += field
                    for k in range(0, (max_column_widths[j] - len(field)) + 1):
                        table_rows += " "

                # Checkmarks for current package in row
                previous_config_column_index = -1
                for l, package_in_config in enumerate(sorted(package[-1])):
                    if previous_config_column_index < 0:
                        current_config_column_index = (COLUMNS[-1][package_in_config])
                    else:
                        current_config_column_index = \
                        (COLUMNS[-1][package_in_config] - previous_config_column_index) -1
                    for m in range(0, current_config_column_index):
                        for n in range(0, max_config_column_width + 1):
                            table_rows += " "
                    table_rows += checkmark
                    if l == len(package[-1]) - 1:
                        break
                    for n in range(0, (max_config_column_width - len(checkmark)) + 1):
                        table_rows += " "
                    previous_config_column_index = current_config_column_index
                if i == len(MAIN_DICT[language]["packages"]) - 1:
                    continue
                table_rows += "\n"

             # Generating the reST code for the table
            rst_table_code = MAIN_DICT[language]["name"]+"\n"
            rst_table_code += language_underline+"\n"
            rst_table_code += table_border+"\n"
            rst_table_code += table_column_header_line+"\n"
            rst_table_code += table_border+"\n"
            rst_table_code += table_rows+"\n"
            rst_table_code += table_border+"\n"
            
            # Writing the output file
            file_handler = open(OUTPUT_DIR+"/RED_Brick_"+language+"_features.table", "w")
            if (file_handler):
                file_handler.write(rst_table_code)
                file_handler.close()
    
            print "\nInfo: "+MAIN_DICT[language]["name"]+" table generated\n"
            
    exit(0)
