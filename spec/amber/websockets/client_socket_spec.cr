require "../../../spec_helper"

module Amber
  describe WebSockets::ClientSocket do
    Spec.after_each do
      Amber::WebSockets::ClientSockets.client_sockets.keys.size.should eq 0
    end

    describe "#channel" do
      it "should add channels" do
        UserSocket.channels[0][:path].should eq "user_room:*"
        UserSocket.channels[0][:channel].should be_a UserChannel
      end
    end

    describe "#get_topic_channel" do
      it "should return the channel if it exists" do
        channel = UserSocket.get_topic_channel("user_room")
        channel.should_not be_nil
      end

      it "should return nil if channel does not exist" do
        channel = UserSocket.get_topic_channel("non_existent_room")
        channel.should be_nil
      end
    end

    describe "#broadcast" do
      it "should broadcast the message to all subscribers" do
        chan = Channel(String).new
        http_server, ws = create_socket_server
        client_socket = Amber::WebSockets::ClientSockets.client_sockets.values.first
        Amber::WebSockets::ClientSockets.add_client_socket(client_socket)
        client_socket.on_message({event: "join", topic: "user_room:939"}.to_json)
        ws.on_message &->(msg : String) { chan.send(msg) }
        channel = UserSocket.channels.first[:channel]
        UserSocket.broadcast("message", "user_room:939", "msg:new", {"message" => "test"})

        msg = JSON.parse(chan.receive)
        msg["event"]?.should eq "message"
        msg["topic"]?.should eq "user_room:939"
        msg["subject"]?.should eq "msg:new"
        msg["payload"]["message"]?.should eq "test"

        client_socket.disconnect!
        http_server.close
      end
    end

    describe "#cookies" do
      it "responds to cookies" do
        ws, client_socket = create_user_socket
        client_socket.responds_to?(:cookies).should eq true
      end
    end

    describe "#session" do
      it "responds to cookies" do
        ws, client_socket = create_user_socket
        client_socket.responds_to?(:session).should eq true
      end

      it "sets a session value" do
        ws, client_socket = create_user_socket
        client_socket.session["name"] = "David"
        client_socket.session["name"].should eq "David"
      end

      it "has a session id" do
        ws, client_socket = create_user_socket
        client_socket.session.id.not_nil!.size.should eq 36
      end
    end

    describe "#initialize" do
      it "should set the socket and socket id" do
        ws, client_socket = create_user_socket
        client_socket.socket.should eq ws
        client_socket.id.should eq ws.object_id
      end
    end

    describe "#on_connect" do
      it "should default to true" do
        ws, client_socket = create_user_socket
        client_socket.on_connect.should be_true
      end
    end

    describe "#disconnect!" do
      it "it should close the socket" do
        http_server, ws = create_socket_server
        client_socket = Amber::WebSockets::ClientSockets.client_sockets.values.first
        client_socket.disconnect!
        client_socket.socket.closed?.should be_true
        client_socket.disconnect!
        http_server.close
      end

      it "should remove the client socket from the ClientSockets list" do
        http_server, ws = create_socket_server
        client_socket = Amber::WebSockets::ClientSockets.client_sockets.values.first
        client_socket.disconnect!
        Amber::WebSockets::ClientSockets.client_sockets.keys.size.should eq 0
        client_socket.disconnect!
        http_server.close
      end
    end

    describe "#authorized?" do
      it "should equal on_connect" do
        ws, client_socket = create_user_socket
        client_socket.authorized?.should eq client_socket.on_connect
      end
    end

    context "#on_message" do
      describe "join event" do
        it "should add a subscription" do
          ws, client_socket = create_user_socket
          client_socket.subscribed_to_topic?("user_room:123").should be_false
          client_socket.on_message({event: "join", topic: "user_room:123"}.to_json)
          client_socket.subscribed_to_topic?("user_room:123").should be_true
        end
      end

      describe "leave event" do
        it "should remove the subscription" do
          ws, client_socket = create_user_socket
          client_socket.on_message({event: "join", topic: "user_room:123"}.to_json)
          client_socket.subscribed_to_topic?("user_room:123").should be_true
          client_socket.on_message({event: "leave", topic: "user_room:123"}.to_json)
          client_socket.subscribed_to_topic?("user_room:123").should be_false
        end
      end
    end
  end
end
