-module(db_api).
-export([store_data/4,retrieve_data/3]).


store_data(settings,User_id,{Setting_type,Setting},Pid)->
	Table_bin = list_to_binary("Settings"),
	Key_bin = list_to_binary(User_id),
	case retrieve_object(Table_bin,Key_bin,Pid) of
		{ok,Object}->
			Map = binary_to_term(riakc_obj:get_value(Object)),
			case maps:find(Setting,Map) of
				{ok,_Current} ->
					New_map = Map#{Setting_type := Setting},
					Map_bin = term_to_binary(New_map),
					New_object = riakc_obj:update_value(Object,Map_bin),
            		{reply,riakc_pb_socket:put(Pid,New_object),Pid};
				error ->
					New_map = Map#{Setting_type=> Setting},
					Map_bin = term_to_binary(New_map),
					New_object = riakc_obj:update_value(Object,Map_bin),
            		{reply,riakc_pb_socket:put(Pid,New_object),Pid}
			end;
		_->
			Map_bin = term_to_binary(#{Setting_type=> Setting}),
			New_object = riakc_obj:new(Table_bin,Key_bin,Map_bin),
			{reply,riakc_pb_socket:put(Pid,New_object),Pid}
	end;
store_data(Table_name,num,Employee_id,Pid)->
		Table_bin = list_to_binary(Table_name),
		Num_bin = list_to_binary("Num_of_employees"),
		Employee_id_bin = term_to_binary(Employee_id),
		case retrieve_object(Table_bin,Num_bin,Pid) of
			{ok,Object}->
				Num_of_employees = binary_to_term(riakc_obj:get_value(Object)),
				New_number_bin = term_to_binary(Num_of_employees + 1),
				Updated_number = riakc_obj:update_value(Object,Num_of_employees + 1),
				riakc_pb_socket:put(Pid,Updated_number),
				New_object = riakc_obj:new(Table_bin,New_number_bin,Employee_id_bin),
				{reply,riakc_pb_socket:put(Pid,New_object),Pid};
			_->
				New_number_bin = term_to_binary(0),
				New_num_object = riakc_obj:new(Table_bin,Num_bin,New_number_bin),
				riakc_pb_socket:put(Pid,New_num_object),
				New_object = riakc_obj:new(Table_bin,New_number_bin,Employee_id_bin),
				{reply,riakc_pb_socket:put(Pid,New_object),Pid}
		end;
store_data(Table_name,Key,{login,Password,User_id},Pid)->
	Table_bin = list_to_binary(Table_name),
	Key_bin = list_to_binary(Key),
	User_bin = term_to_binary(User_id),
	case retrieve_object(Table_bin,Key_bin,Pid) of
		{ok,Object}->
			New_object = riakc_obj:update_value(Object,{Password,User_bin}),
            {reply,riakc_pb_socket:put(Pid,New_object),Pid};
		_->
			New_object = riakc_obj:new(Table_bin,Key_bin,{Password,User_bin}),
			{reply,riakc_pb_socket:put(Pid,New_object),Pid}
	end;
store_data(Table_name,Key,{hours,Date,Hours},Pid)->
	Table_bin = list_to_binary(Table_name),
	Key_bin = list_to_binary(Key),
	case retrieve_object(Table_bin,Key_bin,Pid) of
		{ok,Object}->
			Map = binary_to_term(riakc_obj:get_value(Object)),
			case maps:find(Date,Map) of
				{ok,Value} ->
					New_map = Map#{Date := list_to_integer(Value) + Hours},
					Map_bin = term_to_binary(New_map),
					New_object = riakc_obj:update_value(Object,Map_bin),
            		{reply,riakc_pb_socket:put(Pid,New_object),Pid};
				error ->
					New_map = Map#{Date=> Hours},
					Map_bin = term_to_binary(New_map),
					New_object = riakc_obj:update_value(Object,Map_bin),
            		{reply,riakc_pb_socket:put(Pid,New_object),Pid}
			end;
		_->
			Map_bin = term_to_binary(#{Date=> Hours}),
			New_object = riakc_obj:new(Table_bin,Key_bin,Map_bin),
			{reply,riakc_pb_socket:put(Pid,New_object),Pid}
	end;
store_data(Table_name,Key,Value,Pid)->
	Table_bin = list_to_binary(Table_name),
	Key_bin = list_to_binary(Key),
	Value_bin = list_to_binary(Value),
	case retrieve_object(Table_bin,Key_bin,Pid) of
		{ok,Object}->
			New_object = riakc_obj:update_value(Object,Value_bin),
            {reply,riakc_pb_socket:put(Pid,New_object),Pid};
		_->
			New_object = riakc_obj:new(Table_bin,Key_bin,Value_bin),
			{reply,riakc_pb_socket:put(Pid,New_object),Pid}
	end.


retrieve_data(settings,Key,Pid)->
	case retrieve_object(list_to_binary("Settings"),list_to_binary(Key),Pid) of
		{ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
		Error->
			{reply,Error,Pid}
	end;
retrieve_data(Table_name,{index,Key},Pid)->
	case retrieve_object(list_to_binary(Table_name),integer_to_binary(Key),Pid) of
		{ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
		Error->
			{reply,Error,Pid}
	end;
retrieve_data(employees,Key,Pid)->
	case retrieve_object(list_to_binary("Employees"),list_to_binary(Key),Pid) of
		{ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
		Error->
			{reply,Error,Pid}
	end;
retrieve_data(Table_name,first,Pid)->
    case retrieve_object(list_to_binary(Table_name),list_to_binary("Num_of_employees"),Pid) of
	    {ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end;
retrieve_data(Table_name,Key,Pid) when is_list(Table_name)->
    case retrieve_object(list_to_binary(Table_name),list_to_binary(Key),Pid) of
	    {ok,Object}->
			{reply,binary_to_list(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end;
retrieve_data(usernames,Key,Pid)->
    case retrieve_object(list_to_binary("Usernames"),list_to_binary(Key),Pid) of
	    {ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end;
retrieve_data(Table_name,Key,Pid)->
    case retrieve_object(list_to_binary(Table_name),list_to_binary(Key),Pid) of
	    {ok,Object}->
			{reply,binary_to_term(riakc_obj:get_value(Object)),Pid};
	    Error->
			{reply,Error,Pid}
	end.


retrieve_object(Table_name,Key,Pid)->
	riakc_pb_socket:get(Pid,Table_name,Key).