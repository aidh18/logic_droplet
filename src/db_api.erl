-module(db_api).
-export([store_data/4,retrieve_data/3]).


store_data(_Table_name,_Key,_Value,_Pid)->
	ok.

retrieve_data(_Table_name,_Key,_Pid)->
    {lat,long}.