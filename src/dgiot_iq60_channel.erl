%%--------------------------------------------------------------------
%% Copyright (c) 2020 DGIOT Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(dgiot_iq60_channel).
-behavior(dgiot_channelx).
-author("johnliu").
-include_lib("dgiot_bridge/include/dgiot_bridge.hrl").
-include_lib("dgiot/include/dgiot_socket.hrl").
-include_lib("dgiot/include/logger.hrl").
-include("dgiot_iq60.hrl").
-define(TYPE, <<"IQ60">>).
-define(MAX_BUFF_SIZE, 1024).
-define(SECS, [5, 5 * 60]).
-define(JIAOSHI, 60 * 10 * 1000).

%% API
-export([start/2]).

%% Channel callback
-export([init/3, handle_init/1, handle_event/3, handle_message/2, stop/3]).

%% 注册通道类型
-channel_type(#{

    cType => ?TYPE,
    type => ?PROTOCOL_CHL,
    title => #{
        zh => <<"IQ60采集通道"/utf8>>
    },
    description => #{
        zh => <<"IQ60采集通道"/utf8>>
    }
}).
%% 注册通道参数
-params(#{
    <<"port">> => #{
        order => 1,
        type => integer,
        required => true,
        default => 81888,
        title => #{
            zh => <<"端口"/utf8>>
        },
        description => #{
            zh => <<"侦听端口"/utf8>>
        }
    },
    <<"search">> => #{
        order => 2,
        type => enum,
        required => false,
        default => <<"quick"/utf8>>,
        enum => [<<"nosearch">>, <<"quick">>, <<"normal">>],
        title => #{
            zh => <<"搜表模式"/utf8>>
        },
        description => #{
            zh => <<"搜表模式:nosearch|quick|normal"/utf8>>
        }
    },
    <<"ico">> => #{
        order => 102,
        type => string,
        required => false,
        default => <<"http://dgiot-1253666439.cos.ap-shanghai-fsi.myqcloud.com/shuwa_tech/zh/product/dgiot/channel/IQ60.png">>,
        title => #{
            en => <<"channel ICO">>,
            zh => <<"通道ICO"/utf8>>
        },
        description => #{
            en => <<"channel ICO">>,
            zh => <<"通道ICO"/utf8>>
        }
    }
}).


start(ChannelId, ChannelArgs) ->
    dgiot_channelx:add(?TYPE, ChannelId, ?MODULE, ChannelArgs).

%% 通道初始化
init(?TYPE, ChannelId, #{
    <<"port">> := Port,
    <<"product">> := Products,
    <<"search">> := Search}) ->
    lists:map(fun(X) ->
        case X of
            {ProductId, #{<<"ACL">> := Acl, <<"nodeType">> := 1, <<"thing">> := Thing}} ->
                dgiot_data:insert({dtu, ChannelId}, {ProductId, Acl, maps:get(<<"properties">>, Thing, [])});
            {ProductId, #{<<"ACL">> := Acl, <<"thing">> := Thing}} ->
                dgiot_data:insert({meter, ChannelId}, {ProductId, Acl, maps:get(<<"properties">>, Thing, [])});
            _ ->
                pass
        end
              end, Products),
    dgiot_data:set_consumer(ChannelId, 20),
    State = #state{
        id = ChannelId,
        search = Search
    },
    {ok, State, dgiot_iq60_tcp:start(Port, State)};

init(?TYPE, _ChannelId, _Args) ->
    {ok, #{}, #{}}.

handle_init(State) ->
    {ok, State}.

%% 通道消息处理,注意：进程池调用
%%SELECT username as productid, clientid, connected_at FROM "$events/client_connected" WHERE username = 'bffb6a3a27'
handle_event('client.connected', {rule, #{peername := PeerName}, #{<<"clientid">> := DtuAddr, <<"productid">> := ProductId} = _Select}, State) ->
    [DTUIP, _] = binary:split(PeerName, <<$:>>, [global, trim]),
    DeviceId = dgiot_parse:get_deviceid(ProductId, DtuAddr),
    case dgiot_device:lookup(DeviceId) of
        {ok, _V} ->
            dgiot_device:put(#{<<"objectId">> => DeviceId});
        _ ->
            dgiot_iq60:create_dtu(mqtt, DtuAddr, ProductId, DTUIP)
    end,
    {ok, State};

%% 通道消息处理,注意：进程池调用
handle_event(EventId, Event, State) ->
    ?LOG(error, "EventId ~p Event ~p", [EventId, Event]),
    {ok, State}.

% SELECT clientid, payload, topic FROM "meter"
% SELECT clientid, disconnected_at FROM "$events/client_disconnected" WHERE username = 'dgiot'
% SELECT clientid, connected_at FROM "$events/client_connected" WHERE username = 'dgiot'
handle_message({rule, #{clientid := DevAddr, disconnected_at := _DisconnectedAt}, _Context}, State) ->
    ?LOG(error, "DevAddr ~p ", [DevAddr]),
    {ok, State};

handle_message({rule, #{clientid := DevAddr, payload := Payload, topic := _Topic}, _Msg}, #state{id = ChannelId} = State) ->
    ?LOG(error, "DevAddr ~p Payload ~p ChannelId ~p", [DevAddr, Payload, ChannelId]),
    {ok, State};

handle_message(_Message, State) ->
    {ok, State}.

stop(_ChannelType, _ChannelId, _State) ->
    ok.
