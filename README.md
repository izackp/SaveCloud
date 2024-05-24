# Game Save Cloud
Api to upload and save files associated with games to the cloud. 

#### Questions
Do we handle files ourselves or use solutions like Amazon s3 / garage (https://garagehq.deuxfleurs.fr/)? 
it would simplify complicated features like backup and mirrors

Do we keep file history?
Do we diff saves? it would be necessary if we keep history for large games like minecraft
Should we have profiles or just force another user?

Systems like psp include meta data in the save files as well as store files in coded folders like 'ULUS10529'
Does PARAM.SFO have unique data per user/save ? or will all save files have the same file?

Probably not necessary for v1:

Do we store each individual file in a save and use a manifest?
Clients would be able to compare and submit patches on a per file basis as well as fix file duplication issues.

How do we handle games with the same save format? Lets say there is a graphics only mod or a translation of a game, it will have
a different hash but the save file is still the same and relevant. 

Sometimes the same game can be stored in different formats. We need to support multiple hashes for one game

### Goals
* REST / HTTP API 
* Built in http server to manage internal data and accounts
* C library to make integration easy as well as a cli client


### Napkin API


### User info
```
POST /login?username=isaac&password=guest
{
    "jwt":"abc123",
    "user": { same as below }
}
```

```
POST /register?username=isaac&password=guest&email=someemail@gmail.com
{
    "jwt":"abc123",
    "user": { same as below }
}
```

```
GET PUT DELETE /user
{
    "id":"uuid",
    "username":"Isaac",
    "avatar":"Base64;asdadsasd",
    "email":"someemail@gmail.com",
    "created_at":"..",
    "updated_at":".."
}
```

```
GET /user/games
[{
    "id":"uuid",
    "hash":"asdadsasd",
    "created_at":"..",
    "updated_at":"..",
    //Not necessary?
    "name":"The Battle for Wesnoth",
    "version":"1.18.0",
}]
```
Returns all games where a user has a save

```
GET/DELETE /user/games/:id
GET/DELETE /user/games/:hash
```
A single item of the above result where a user has a save

```
GET/DELETE /user/games/:hash
{
    "id":"uuid",
    "hash":"asdadsasd",
    "created_at":"..",
    "updated_at":"..",
    "parent" : { //Including parent 
        "id":"uuid",
        "hash":"asdadsasd",
        "created_at":"..",
        "updated_at":".."
    },
    //or
    "parent_id":"uuid",
    "unique_save_format": false //Means the save will work for this game and the parent
}
```


```
GET /games/:hash
GET /games/:id
GET /games/by_family/:id
{
    "id": "uuid",
    "hash": "asdadsasd",
    "name": "The Battle for Wesnoth",
    "version": "1.18.0",
    "platform": "windows",
    "family_id": "uuid",
    "created_at": "..",
    "updated_at": "..",
    "patched_game_info": {
        "base_game" : { //For when the game is a mod/patch of an existing game
            "id": "uuid",
            "hash": "asdadsasd",
            "created_at": "..",
            "updated_at": "..",
            etc
        },
        //or
        "base_game_id": "uuid",
        "breaks_save_format": true
    },
    "breaks_save_format": false
}
```
Allow user to submit changes, but must be reviewed and approved

```
GET/DELETE/POST /user/games/:id/saves
GET/DELETE/POST /user/games/:hash/saves
[{
    "id":"uuid",
    "game_id":"uuid",
    "sequntial_id":"uuid",
    "sequence":"2",
    "url":"http://path.to/save.zip",
    "screenshot":"Base64;asdadsasd", //Maybe a url? it would need to be less than 100kb for embedded to be viable
    "created_at":"..",
    "updated_at":"..",
    //Maybe include patch support? not necessisary for v1
    "patch_from_last_save":"http://path.to/patch.zip",
    "hash":"abc", //To verify the patch applies to your save
}]
```
