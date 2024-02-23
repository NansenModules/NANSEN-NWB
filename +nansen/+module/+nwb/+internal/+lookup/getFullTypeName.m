function fullName = getFullTypeName(shortName)
% getFullTypeName - Get package-prefixed name from short name

    persistent typeMap
    if isempty(typeMap)
        rootFolder = matnwb.misc.getMatnwbDir();
        filePaths = utility.dir.recursiveDir(fullfile(rootFolder, '+matnwb', '+types'), ...
            'FileType', 'm', 'OutputType', 'FilePath', 'IgnoreList', {'+util'});

        packagePrefixedNames = utility.path.abspath2funcname(filePaths);
        shortNames = utility.string.getSimpleClassName(packagePrefixedNames);

        typeMap = dictionary( string(shortNames), string(packagePrefixedNames)); 
    end

    fullName = typeMap(shortName);
end