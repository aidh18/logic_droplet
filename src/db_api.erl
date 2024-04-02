-module(db_api).
-export([store_data/4,retrieve_data/3]).


store_data(Table_name,Key,Value,Pid) when not is_tuple(Value)->
	Table_bin = list_to_binary(Table_name),
	Key_bin = list_to_binary(Key),
	Value_bin = list_to_binary(Value),
	case retrieve_object(Table_bin, Key_bin, Pid) of
		{ok,Object}->
			New_object = riakc_obj:update_value(Object, Value_bin),
            {reply,riakc_pb_socket:put(Pid, New_object),Pid};
		_->
			New_object = riakc_obj:new(Table_bin, Key_bin, Value_bin),
			{reply,riakc_pb_socket:put(Pid, New_object),Pid}
	end;
store_data(Table_name,Key,Value,Pid)->
	Table_bin = list_to_binary(Table_name),
	Key_bin = list_to_binary(Key),
	Value_bin = term_to_binary(Value),
	case retrieve_object(Table_bin, Key_bin, Pid) of
		{ok,Object}->
			New_object = riakc_obj:update_value(Object, Value_bin),
            {reply,riakc_pb_socket:put(Pid, New_object),Pid};
		_->
			New_object = riakc_obj:new(Table_bin, Key_bin, Value_bin),
			{reply,riakc_pb_socket:put(Pid, New_object),Pid}
	end.


retrieve_data(Table_name,Key,Pid) when Table_name =:= "Packages"->
    case retrieve_object(list_to_binary("Packages"),Key,Pid) of
	    {ok,Object}->
			{reply,binary_to_list(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end;
retrieve_data(Table_name,Key,Pid) when Table_name =:= "Locations"->
    case retrieve_object(list_to_binary(Table_name),list_to_binary(Key),Pid) of
	    {ok,Object}->
			io:format("found!!!"),
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
	    Error->
			io:format("not found!!!"),
			{reply,Error,Pid}
	end;
retrieve_data(Table_name,Key,Pid)->
    case retrieve_object(list_to_binary(Table_name),list_to_binary(Key),Pid) of
	    {ok,Object}->
			{reply,binary_to_list(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end.


retrieve_object(Table_name,Key,Pid)->
	riakc_pb_socket:get(Pid, Table_name, Key).