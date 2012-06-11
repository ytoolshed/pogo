
var fs = require('fs'), path = require('path');

// Get the loader module name
var pathItems = __dirname.split('/');
var loaderModule = pathItems[pathItems.length-1];

// Get the src directory
var srcDirectory = __dirname+'/../';

var meta_properties = {};

fs.readdir(srcDirectory, function(err, files) {
        files.forEach(function(f) {
                if(f != 'build.xml' && f != loaderModule) {
                        
                        var buildProperties = srcDirectory+f+'/build.properties';
                        path.exists(buildProperties, function(exists) {  
                        
                                if(exists) {
                                
                                        fs.readFile(buildProperties, function (err, data) {
                                                if (err) throw err;
                        
                                                
                                                var componentName = null, 
                                                         requires = [],
                                                         lang = [];
                                                
                                                var lines = data.toString().split("\n");
                                                lines.forEach(function(line) {
                                                        
                                                        // component name
                                                        var m = line.match(/^\s*component\s*=\s*([^\n]*)/);
                                                        if(m){
                                                                componentName = m[1];
                                                        }
                                                        
                                                        // required modules
                                                        var m = line.match(/^\s*component.requires\s*=\s*([^\n]*)/);
                                                        if(!m) {
                                                                m = line.match(/^\s*component.use\s*=\s*([^\n]*)/);
                                                        }
                                                        if(m){
                                                                var req = m[1].trim().split(',');
                                                                if(req != "") {
                                                                        requires = req;
                                                                        for(var i = 0 ; i < requires.length ; i++) {
                                                                                requires[i] = requires[i].trim();
                                                                        }
                                                                }
                                                                else {
                                                                        requires = [];
                                                                }
                                                        }
                                                        
                                                        // lang
                                                        var m = line.match(/^\s*component.lang\s*=\s*([^\n]*)/);
                                                        if(m){
                                                                var req = m[1].trim().split(',');
                                                                if(req != "") {
                                                                        lang = req;
                                                                        for(var i = 0 ; i < lang.length ; i++) {
                                                                                lang[i] = lang[i].trim();
                                                                        }
                                                                }
                                                        }
                                                        
                                                });
                                                
                                                if( !componentName || !requires ) {
                                                        console.log("Unable to parse build.properties in folder: "+buildProperties);
                                                }
                                                else {
                                                        meta_properties[componentName] = {
                                                                        "path": componentName+"/"+componentName+"-min.js",
                                                                        "requires": requires
                                                        };
                                                        if(lang.length > 0) {
                                                                meta_properties[componentName].lang = lang;
                                                        }
                                                        
                                                        
                                                        // check if the module is skinable:
                                                        //  ie: assets && assets/moduleName-core.css && assets/skins
                                                        var component = srcDirectory+f+'/';
                                                        if( path.existsSync(component+'assets') &&
                                                                 path.existsSync(component+'assets/'+componentName+'-core.css') &&
                                                                 path.existsSync(component+'assets/skins') ) {
                                                                meta_properties[componentName].skinnable = true;        
                                                        }
                                                        
                                                }
                        
                                        });
                                        
                                }
                                
                        });
                        
                }
        });
});


process.on('exit', function () {

        var str = "\n\
// Note: this file is auto-generated by meta_join.js. Don't Modify me !\n\
YUI().use(function(Y) {\n\
\n\
        /**\n\
        * YUI 3 module metadata\n\
        * @module "+loaderModule+"\n\
         */\n\
        var CONFIG = {\n\
                groups: {\n\
                        'pogo': {\n\
                                base: '/pogo/js/build/',\n\
                                combine: false,\n\
                                modules: "+JSON.stringify(meta_properties)+"\n\
                        }\n\
                }\n\
        };\n\
\n\
        if(typeof YUI_config === 'undefined') { YUI_config = {groups:{}}; }\n\
        Y.mix(YUI_config.groups, CONFIG.groups);\n\
\n\
});";

        fs.writeFileSync( __dirname+'/js/loader.js', str);
        
});
