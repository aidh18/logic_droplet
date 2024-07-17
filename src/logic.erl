%% @author Lee Barney
%% @copyright 2022 Lee Barney licensed under the <a>
%%        rel="license"
%%        href="http://creativecommons.org/licenses/by/4.0/"
%%        target="_blank">
%%        Creative Commons Attribution 4.0 International License</a>
%%
%%
-module(logic).
-behavior(gen_server).


%% API
-export([start/0,start/3,stop/0]).

%% gen_server callbacks
-export([init/1,request_hours_api/2,request_login_api/2,request_name_api/1,
request_settings_api/1,update_hours_api/3,update_login_api/3,update_name_api/2,
update_settings/3,get_hours/2,get_employees/4,add_employees_api/2,test/2,
handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server assuming there is only one server started for
%% this module. The server is registered locally with the registered
%% name being the name of the module.
%%
%% @end
%%--------------------------------------------------------------------
-spec start()-> {ok,pid()} | ignore | {error,term()}.
start()->
    gen_server:start_link({local,?MODULE},?MODULE,[],[]).
%%--------------------------------------------------------------------
%% @doc
%% Starts a server using this module and registers the server using
%% the name given.
%% Registration_type can be local or global.
%%
%% Args is a list containing any data to be passed to the gen_server's
%% init function.
%%
%% @end
%%--------------------------------------------------------------------
-spec start(atom(),atom(),atom())-> {ok,pid()} | ignore | {error,term()}.
start(Registration_type,Name,Args)->
    gen_server:start_link({Registration_type,Name},?MODULE,Args,[]).


%%--------------------------------------------------------------------
%% @doc
%% Stops the server gracefully
%%
%% @end
%%--------------------------------------------------------------------
-spec stop()-> {ok} | {error,term()}.
stop()-> gen_server:call(?MODULE,stop).

%% Any other API functions go here.
add_employees_api(Employer_id,Employee_id)->
    Node = rrobin:next(),
    gen_server:cast(Node,{add_employees,{Employer_id,Employee_id}}).

request_hours_api(Is_employer,User_id)->
    Node = rrobin:next(),
    case gen_server:call(Node,{request_hours,{Is_employer,User_id}}) of
        {error,invalid_id}-> 500;
        {error,empty_id}-> 500;
        {error,notfound}-> 500;
        Response-> Response
    end.

request_login_api(Username,Password)->
    Node = rrobin:next(),
    case gen_server:call(Node,{request_login,{Username,Password}}) of
        {error,invalid_id}-> 500;
        {error,empty_id}-> 500;
        {error,notfound}-> 500;
        Response-> Response
    end.

request_name_api(User_id)->
    Node = rrobin:next(),
    case gen_server:call(Node,{request_name,User_id}) of
        {error,invalid_id}-> 500;
        {error,empty_id}-> 500;
        {error,notfound}-> 500;
        Response-> Response
    end.

request_settings_api(User_id)->
    Node = rrobin:next(),
    case gen_server:call(Node,{request_settings,User_id}) of
        {error,invalid_id}-> 500;
        {error,empty_id}-> 500;
        {error,notfound}-> 500;
        Response-> Response
    end.

update_settings(User_id,Setting_type,Setting)->
    Node = rrobin:next(),
    gen_server:cast(Node,{update_settings,{User_id,Setting_type,Setting}}).

update_hours_api(User_id,Date,Hours)->
    Node = rrobin:next(),
    gen_server:cast(Node,{update_hours,{User_id,Date,Hours}}).

update_login_api(User_id,Username,New_password)->
    Node = rrobin:next(),
    gen_server:cast(Node,{update_login,{User_id,Username,New_password}}).

update_name_api(User_id,Name)->
    Node = rrobin:next(),
    gen_server:cast(Node,{update_name,{User_id,Name}}).

get_hours(Employee_id,Db_pid)->
    Name = request_name_api(Employee_id),
    {_,Hours,_} = db_api:retrieve_data(employees,Employee_id,Db_pid),
    [Name,Hours].

get_employees(_,Index,Hours,_) when Index < 0->
    Hours;
get_employees(Employer_id,Index,Hours,Db_pid)->
    {_,Employee_id,_} = db_api:retrieve_data(Employer_id,{index,Index},Db_pid),
    Data = get_hours(Employee_id,Db_pid),
    get_employees(Employer_id,Index - 1,Hours ++ [Data],Db_pid).

test(Table_name,Key)->
    Node = rrobin:next(),
    gen_server:call(Node,{test,{Table_name,Key}}).


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @end
%%--------------------------------------------------------------------
-spec init(term())-> {ok,term()} | {ok,term(),number()} | ignore | {stop,term()}.
init([])->
    case riakc_pb_socket:start_link("db1.aidanstacey.com",8087) of
        {ok,Db_pid}-> {ok,Db_pid};
        _-> {stop,link_failure}
    end.
% logic:request_hours_api(true,"testboi1").
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @end
%%--------------------------------------------------------------------
-spec handle_call(Request::term(),From::pid(),State::term())->
                                  {reply,term(),term()}  |
                                  {reply,term(),term(),integer()}  |
                                  {noreply,term()}  |
                                  {noreply,term(),integer()}  |
                                  {stop,term(),term(),integer()} |
                                  {stop,term(),term()}.
handle_call({request_hours,{Is_employer,User_id}},_From,Db_pid)->
    if
        not is_list(User_id)->
            {reply,{error,invalid_id},Db_pid};
        true->
            case User_id =:= "" of
                true->
                    {reply,{error,empty_id},Db_pid};
                _->
                    if
                        Is_employer->
                            {_,Num_of_employees,_} = db_api:retrieve_data(User_id,
                                                                first,
                                                                Db_pid),
                            if
                                is_integer(Num_of_employees)->
                                    {reply,get_employees(User_id,Num_of_employees,[],Db_pid),Db_pid};
                                true->
                                    {reply,{error,invalid_id,Db_pid}}
                            end;
                        true->
                            {reply,get_hours(User_id,Db_pid),Db_pid}
                    end
            end
    end;
handle_call({request_login,{Username,Password}},_From,Db_pid)->
    if
        not is_list(Username)->
            {reply,{error,invalid_username},Db_pid};
        not is_list(Password)->
            {reply,{error,invalid_password},Db_pid};
        true->
            if
                Username =:= ""->
                    {reply,{error,empty_username},Db_pid};
                Password =:= ""->
                    {reply,{error,empty_username},Db_pid};
                true->
                    {_,{Saved,User_id},_} = db_api:retrieve_data(usernames,
                                                                Username,
                                                                Db_pid),
                    Hashed = crypto:hash(sha256,Password),
                    if
                        Saved == Hashed->
                            {reply,binary_to_term(User_id),Db_pid};
                        true->
                            {reply,invalid_password,Db_pid}
                    end
            end
    end;
handle_call({request_name,User_id},_From,Db_pid)->
    if
        not is_list(User_id)->
            {reply,{error,invalid_id},Db_pid};
        true->
            if
                User_id =:= ""->
                    {reply,{error,empty_id},Db_pid};
                true->
                    db_api:retrieve_data("Names",User_id,Db_pid)
            end
    end;
handle_call({request_settings,User_id},_From,Db_pid)->
    if
        not is_list(User_id)->
            {reply,{error,invalid_id},Db_pid};
        true->
            if
                User_id =:= ""->
                    {reply,{error,empty_id},Db_pid};
                true->
                    db_api:retrieve_data(settings,User_id,Db_pid)
            end
    end;
handle_call({test,{Table_name,Key}},_From,Db_pid)->
    db_api:retrieve_data(Table_name,Key,Db_pid);
handle_call(stop,_From,_State)->
        {stop,normal,
                replace_stopped,
          down}; %% setting the server's internal state to down
handle_call({Unknown,_},From,_Db_pid)->
    {reply,{error,unknown_call,Unknown},From}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @end
%%--------------------------------------------------------------------
%%
handle_cast({update_hours,{User_id,Date,Hours}},Db_pid)->
    if
        not is_list(User_id)->
            io:format("update_hours: User_id is not a list."),
            {noreply,Db_pid};
        true->
            case User_id =:= "" of
                true->
                    io:format("update_hours: User_id is empty."),
                    {noreply,Db_pid};
                _->
                    db_api:store_data("Employees",User_id,{hours,Date,Hours},
                                                Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast({update_login,{User_id,Username,New_password}},Db_pid)->
    if
        not is_list(User_id)->
            io:format("update_login: User_id is not a list."),
            {noreply,Db_pid};
        not is_list(Username)->
            io:format("update_login: Username is not a list."),
            {noreply,Db_pid};
        not is_list(New_password)->
            io:format("update_login: New_password is not a list."),
            {noreply,Db_pid};
        true->
            if
                User_id =:= ""->
                    io:format("update_login: User_id is empty."),
                    {noreply,Db_pid};
                Username =:= ""->
                    io:format("update_login: Username is empty."),
                    {noreply,Db_pid};
                New_password =:= ""->
                    io:format("update_login: New_password is empty."),
                    {noreply,Db_pid};
                true->
                    db_api:store_data("Usernames",Username,
                                    {login,crypto:hash(sha256,New_password),
                                    User_id},Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast({update_name,{User_id,Name}},Db_pid)->
    if
        not is_list(User_id)->
            io:format("update_name: User_id is not a list."),
            {noreply,Db_pid};
        not is_list(Name)->
            io:format("update_name: Name is not a list."),
            {noreply,Db_pid};
        true->
            if
                User_id =:= ""->
                    io:format("update_name: User_id is empty."),
                    {noreply,Db_pid};
                Name =:= ""->
                    io:format("update_name: Name is empty."),
                    {noreply,Db_pid};
                true->
                    db_api:store_data("Names",User_id,Name,
                                                Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast({update_settings,{User_id,Setting_type,Setting}},Db_pid)->
    if
        not is_list(User_id)->
            io:format("update_settings: User_id is not a list."),
            {noreply,Db_pid};
        not is_list(Setting_type)->
            io:format("update_settings: Setting_type is not a list."),
            {noreply,Db_pid};
        not is_list(Setting)->
            io:format("update_settings: Setting is not a list."),
            {noreply,Db_pid};
        true->
            if
                User_id =:= ""->
                    io:format("update_settings: User_id is empty."),
                    {noreply,Db_pid};
                Setting_type =:= ""->
                    io:format("update_settings: Setting_type is empty."),
                    {noreply,Db_pid};
                Setting =:= ""->
                    io:format("update_settings: Setting is empty."),
                    {noreply,Db_pid};
                true->
                    db_api:store_data(settings,User_id,{Setting_type,Setting},
                                                Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast({add_employees,{Employer_id,Employee_id}},Db_pid)->
    if
        not is_list(Employer_id)->
            io:format("update_login: Employer_id is not a list."),
            {noreply,Db_pid};
        not is_list(Employee_id)->
            io:format("update_login: Employee_id is not a list."),
            {noreply,Db_pid};
        true->
            if
                Employer_id =:= ""->
                    io:format("update_login: Employer_id is empty."),
                    {noreply,Db_pid};
                Employee_id =:= ""->
                    io:format("update_login: Employee_id is empty."),
                    {noreply,Db_pid};
                true->
                    db_api:store_data(Employer_id,num,Employee_id,
                                        Db_pid),
                    {noreply,Db_pid}
            end
    end;
handle_cast(_,Db_pid)->
    {noreply,Db_pid}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @end
-spec handle_info(Info::term(),State::term())-> {noreply,term()}  |
                                   {noreply,term(),integer()}  |
                                   {stop,term(),term()}.
handle_info(_Info,State)->
    {noreply,State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns,the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @end
%%--------------------------------------------------------------------
-spec terminate(Reason::term(),term())-> term().
terminate(_Reason,_State)->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @end
%%--------------------------------------------------------------------
-spec code_change(term(),term(),term())-> {ok,term()}.
code_change(_OldVsn,State,_Extra)->
    {ok,State}.

