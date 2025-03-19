lib.addCommand('cdb_show', {
    help = 'Display the ChiliadDB explorer UI',
    restricted = 'group.chiliaddb',
}, function(source, args, raw)
    ShowDatabaseCollections(source)
end)

lib.addCommand('cdb_export', {
    help = 'Export ChiliadDB to json file',
    restricted = 'group.chiliaddb',
}, function(source, args, raw)
    BackupDatabase()
end)

lib.addCommand('cdb_import', {
    help = 'Import data from json file to ChiliadDB',
    restricted = 'group.chiliaddb',
}, function(source, args, raw)
    RestoreDatabase()
end)

lib.addCommand('cdb_drop', {
    help = 'Drop the entire ChiliadDB, a collection or a document',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to wipe',
            optional = true,
        },
        {
            name = 'index',
            type = 'number',
            help = 'Specify the collection name to wipe',
            optional = true,
        },
    }
}, function(source, args, raw)
    if args.collection then
        if args.collection == 'all' then
            DropDatabase()
        else
            DropCollection(args.collection)
        end
    elseif args.collection and args.index then
        DeleteDocument(args.collection, args.index)
    end
end)

lib.addCommand('cdb_sync', {
    help = 'Sync ChiliadDB to KVP',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to wipe',
            optional = true,
        },
    }
}, function(source, args, raw)
    SyncDataToKvp()
end)

lib.addCommand('cdb_print', {
    help = 'Print information about the ChiliadDB',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to print',
            optional = true,
        },
        {
            name = 'id',
            type = 'number',
            help = 'Specify the collection and id to print',
            optional = true,
        },
    }
}, function(source, args, raw)
    PrintDatabaseInfo(args)
end)

lib.addCommand('cdb_renamecollection', {
    help = 'Rename an existing collection within ChiliadDB',
    restricted = 'group.chiliaddb',
    params = {
        {
            name = 'collection',
            type = 'string',
            help = 'Specify the collection name to rename',
        },
        {
            name = 'newName',
            type = 'string',
            help = 'Specify the new name for the collection',
        },
    }
}, function(source, args, raw)
    RenameCollection(args.collection, args.newName, "user command")
end)