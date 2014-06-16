#!/usr/bin/env python
# -*- coding: utf-8 -*-

if __name__ == "__main__":
    from os import path
    from sys import argv
    
    if len(argv) != 2:
        print "\nError: Too many or too few parameters (provide image configuration name)\n"
        exit(1)
        
    # Defining paths
    SCRIPT_RUN_DIR = path.dirname(path.abspath(__file__))
    BUILD_DIR      = SCRIPT_RUN_DIR+"/build"
    CONFIG_DIR     = SCRIPT_RUN_DIR+"/config"
    PATCHES_DIR    = SCRIPT_RUN_DIR+"/patches"
    
    if not path.isdir(BUILD_DIR) or not path.isdir(BUILD_DIR) or \
       not path.isdir(BUILD_DIR):
        print "\nError: Wrong directory structure\n"
        exit(1)
    if not path.exists(CONFIG_DIR + "/image_" + argv[1] + ".conf"):
        print "\nError: No such configuration\n"
        exit(1)
