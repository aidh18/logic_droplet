%%%-------------------------------------------------------------------
%% @doc logic_droplet top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(tracker_sup).

-behaviour(supervisor).

-export([start/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

start() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%% sup_flags() = #{strategy => strategy(),         % optional
%%                 intensity => non_neg_integer(), % optional
%%                 period => pos_integer()}        % optional
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
init([]) ->
    SupFlags = #{strategy => one_for_one,
                 intensity => 2,
                 period => 3600},
    ChildSpecs = [
        child(tracker1, logic, worker),
        child(tracker2, logic, worker),
        child(tracker3, logic, worker),
        child(tracker4, logic, worker)
    ],
    {ok, {SupFlags, ChildSpecs}}.

%% internal functions
child(Id, Module, Type)->
%% child_spec() = #{id => child_id(),       % mandatory
%%                  start => mfargs(),      % mandatory
%%                  restart => restart(),   % optional
%%                  shutdown => shutdown(), % optional
%%                  type => worker(),       % optional
%%                  modules => modules()}   % optional
    #{id => Id,
	  start => {Module,start,[local, Id, []]},
	  restart => permanent,
	  shutdown => 2000,
	  type => Type,
	  modules => [Module]}.
