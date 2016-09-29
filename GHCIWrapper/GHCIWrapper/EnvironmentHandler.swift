//
//  EnvironmentHandler.swift
//  REPLWrapper
//
//  Created by Christian Lundtofte on 29/09/2016.
//  Copyright © 2016 Christian Lundtofte. All rights reserved.
//

import Foundation

class EnvironmentHandler {
    static let shared = EnvironmentHandler()
    
    private var selectedEnvironmentName:String?
    private var environmentLoadArgument:String?
    
    private var environmentNameArray:Array<String> = []
    private var environmentFileTypes:Array<String> = []
    private var environmentPaths:Array<String> = []
    
    
    var environmentNames:Array<String> {
        get {
            return self.environmentNameArray
        }
    }
    
    var selectedEnvironmentFileTypes:Array<String> {
        get {
            return environmentFileTypes
        }
    }
    
    var defaultPaths:Array<String> {
        get {
            return environmentPaths
        }
    }
    
    var selectedEnvironment:String? {
        get {
            return UserDefaults.standard.value(forKey: "EnvironmentName") as? String
        }
        set(new) {
            self.selectedEnvironmentName = new
            if new != nil {
                self.saveEnvironment(env: new!)
            }
        }
    }
    
    var selectedEnvironmentLoadingArgument:String? {
        get {
            return environmentLoadArgument
        }
    }
    
    init() {
        // Environment filer
        if let envsPath = Bundle.main.path(forResource: "Environments", ofType: "plist") {
            let dic = NSDictionary(contentsOfFile: envsPath)
            if let envAr = dic?.value(forKey: "Envs") as? Array<String> {
                self.environmentNameArray = envAr
            }
        }
        
        // Hvis vi har environment
        if hasEnvironment() {
            self.selectedEnvironmentName = UserDefaults.standard.value(forKey: "EnvironmentName") as! String?
            self.loadEnvironment()
        }
    }
    
    func loadEnvironment() {
        guard let env = self.selectedEnvironmentName else { return }
        
        print("Loader: \(env)")
        if let path = Bundle.main.path(forResource: env, ofType: "plist"),
            let envDic = NSDictionary(contentsOfFile: path),
            let types = envDic.value(forKey: "FileTypes") as? Array<String>,
            let paths = envDic.value(forKey: "KnownPaths") as? Array<String>,
            let loading = envDic.value(forKey: "LoadArgument") as? String {
            
            print("Dic: \(envDic)")
            
            self.environmentFileTypes = types
            self.environmentPaths = paths
            self.environmentLoadArgument = loading
        }
    }
    
    func hasEnvironment() -> Bool {
        return (UserDefaults.standard.value(forKey: "EnvironmentName") != nil)
    }

    func saveEnvironment(env: String) {
        UserDefaults.standard.setValue(env, forKey: "EnvironmentName")
        UserDefaults.standard.synchronize()
    }
}
