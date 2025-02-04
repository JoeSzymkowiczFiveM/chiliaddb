# ChiliadDB

A NoSQL-like datastore and syntax for the built-in FiveM KVP storage system. After I was told to "Just use KVP" a thousand times, and realizing how inaccessible KVP actually was, I started looking around for any kind of existing driver/wrapper for it. While I initially worked a bit with [0xludb-fivem](https://github.com/0xwal/0xludb-fivem), it did not suit my needs and lacked core features and functionality. ChiliadDB is my attempt at making KVP more-usable and able to be used as a drop-in replaced for frameworks like Ox and Qbox, while using a syntax I was familiar with. 

NOTE: Like Trevor Phillips, the API and syntax should be considered unstable. It has not been tested on a real production server, with an active playerbase, and this is not recommended for production usage. I still have work planned for this and PRs are always welcome. Also, the UI has very basic delete and updata capability, which has not been fully tested or validated. It has a lot of capability that could allow you to break your data. Beware.

If you are interested in the project, come say Hi in Discord.


## ✨ Features
- NoSQL-like datastore for FiveM KVP storage system
- No need for external database services. The database is in FiveM. Establish your collections and data structures as you code
- Built-in database explorer UI to browse and edit the datastore
- MongoDB-like syntax
- Commands for dropping collections, deleting documents, exporting, and importing data
- Convars for user permissions and print level settings


## ✅ Dependencies
 - [ox_lib](https://github.com/overextended/ox_lib) v3.28.1 or higher


## 👀 Usage

- Add the following line to the fxmanifest of the resource you want to use chiliaddb in:
```
server_script '@chiliaddb/init.lua'
```


## ⌨️ Documentation

[ChiliadDB Functions](EXAMPLES.md)

[Advanced Query Operators](OPERATORS.md)


## ⌨️ Commands

 - `/cdb_print {collection name} or 'all', {document id}` This command prints the requested data. I've been using this in the server console, as I do a lot of work from the terminal, and I'm not logged into the game. I found it helpful, maybe you will too.

  - `/cdb_drop {collection name} or 'all', {document id}` This command deletes the entire database, a single collection or a single document within that specified collection, based on the passed arguments.

 - `/cdb_export` This exports the whole datastore to a `database.json` file in the resource folder. This lets me look at the data and change it, and load it back in with the `cdb_import` command. This is also good for making backups of the database.

  - `/cdb_import` This wipes the existing database and reloads it with the contents of the `database.json` file, from the resource folder. I dont have any validation for this, so be very careful when using this.

 ## #️⃣ Convars

Please add the following convars to your server config
```bash
### chiliaddb convars
# Gives specified users the permission to use chiliaddb commands and ui
add_ace group.admin group.chiliaddb allow
add_principal identifier.license:YourFiveMLicense group.chiliaddb

# Set the print level for the chiliaddb.
set ox:printlevel:chiliaddb "error"
```


## 💢 To Do

- The UI has very basic delete and updata capability, which has not been fully tested or validated. It has a lot of capability that could allow you to break your data. Beware.
- More functions and options in the wrapper itself.
- Optimizations and more validation.


## 👀 Tips

- In converting several frameworks and scripts in the development of this driver, I found that tables are `json.encode`'d when are inserted into the database. These tables no longer need to be `decoded` so keep an eye out for these if you're converting existing code.
- At the moment, there is not much notification or validation of mismatched types on the fields vs passed query parameters. Be sure the datatypes of compared fields are matching.


## 👐 Credit

Big thanks to [Snipe](https://github.com/snipe-scripts) for constructing the datastore UI and the constructive conversations over the years. Also shoutout to [darktrovx](https://github.com/darktrovx) and [Zoo](https://github.com/FjamZoo) for discussions regarding datastores and fivem technical randomness. Also, huge shoutout to the [Overextended](https://github.com/overextended) group for technical discussions and support throughout most of the work I've done.


## Discord

[Joe Szymkowicz FiveM Development](https://discord.gg/5vPGxyCB4z)
