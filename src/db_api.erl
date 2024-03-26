-module(db_api).
-export([store_data/4,retrieve_data/3]).


store_data(Table_name,Key,Value,Pid)->
	case retrieve_object(Table_name, Key, Pid) of
		{ok,Object}->
			New_object = riakc_obj:update_value(Object, Value),
            {reply,riakc_pb_socket:put(Pid, New_object),Pid};
		_->
			New_object = riakc_obj:new(Table_name, Key, Value),
			{reply,riakc_pb_socket:put(Pid, New_object),Pid}
	end.
	

retrieve_data(<<"Packages">>,Key,Pid)->
    case retrieve_object(<<"Packages">>,Key,Pid) of 
	    {ok,Object}->
			{reply,binary_to_list(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end;
retrieve_data(<<"Locations">>,Key,Pid)->
    case retrieve_object(<<"Locations">>,Key,Pid) of 
	    {ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end;
retrieve_data(Binary_table_name,Key,Pid) when is_binary(Binary_table_name)->
    case retrieve_object(Binary_table_name,Key,Pid) of 
	    {ok,Object}->
			{reply,binary_to_list(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end.

retrieve_object(Table_name,Key,Pid)->
	riakc_pb_socket:get(Pid, Table_name, Key).