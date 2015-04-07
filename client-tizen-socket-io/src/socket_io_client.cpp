#include "sio_client.h"
#include "socket_io_client.hpp"

#define HIGHLIGHT(__O__) std::cout<<"\e[1;31m"<<__O__<<"\e[0m"<<std::endl
#define EM(__O__) std::cout<<"\e[1;30;1m"<<__O__<<"\e[0m"<<std::endl
#include <functional>
#include <iostream>
#include <mutex>
#include <condition_variable>
#include <string>

#include <pthread.h>
#include <unistd.h>

using namespace sio;
using namespace std;

std::mutex _lock;

std::condition_variable_any _cond;
bool connect_finish = false;
int participants = 0;

class connection_listener
{
    sio::client &handler;

public:

    connection_listener(sio::client& h):
    handler(h)
    {
    }


    void on_connected()
    {
        _lock.lock();
        _cond.notify_all();
        connect_finish = true;
        _lock.unlock();
    }
    void on_close(client::close_reason const& reason)
    {
        std::cout<<"sio closed "<<std::endl;
        dlog_print(DLOG_FATAL, LOG_TAG, "sio closed");
        //exit(0);
    }

    void on_fail()
    {
        std::cout<<"sio failed "<<std::endl;
        dlog_print(DLOG_FATAL, LOG_TAG, "sio closed");
        //exit(0);
    }
};


extern "C" {
	void socket_io_client()
	{


		sio::client h;
		connection_listener l(h);
		dlog_print(DLOG_FATAL, LOG_TAG, "Connect Start");
		h.set_connect_listener(std::bind(&connection_listener::on_connected, &l));
		dlog_print(DLOG_FATAL, LOG_TAG, "Set ConnectListener");

		h.set_close_listener(std::bind(&connection_listener::on_close, &l,std::placeholders::_1));
		dlog_print(DLOG_FATAL, LOG_TAG, "Set ClosetListener");

		h.set_fail_listener(std::bind(&connection_listener::on_fail, &l));
		dlog_print(DLOG_FATAL, LOG_TAG, "Set FaileListener");

		h.connect("http://112.108.40.166:5000");
		dlog_print(DLOG_FATAL, LOG_TAG, "Connect");

		_lock.lock();
		dlog_print(DLOG_FATAL, LOG_TAG, "Lock");
		if(!connect_finish)
		{
			dlog_print(DLOG_FATAL, LOG_TAG, "!!!");
			_cond.wait(_lock);
		}
		dlog_print(DLOG_FATAL, LOG_TAG, "unlock");
		_lock.unlock();

		dlog_print(DLOG_FATAL, LOG_TAG, "emit connectMessage");
		h.emit("connectMessage", "{\"project\":\"rapidjson\",\"stars\":10}");

		dlog_print(DLOG_FATAL, LOG_TAG, "bind connectMessage");
		h.bind_event("connectMessage", [&](string const& name, message::ptr const& data, bool isAck,message::ptr &ack_resp){
			_lock.lock();

			unsigned int pid = (unsigned) getpid();
			dlog_print(DLOG_FATAL, LOG_TAG, "bind connectMessage lamda function %u", pid);

//			string user = data->get_map()["error"]->get_string();
//			string message = data->get_map()["success"]->get_string();
//
//			dlog_print(DLOG_FATAL, LOG_TAG, "connectMessage %s:%s", user.c_str(), message.c_str());

			_lock.unlock();
	    });

		unsigned int pidThread = (unsigned) getpid();
		dlog_print(DLOG_FATAL, LOG_TAG, "close %u", pidThread);

		while(1){

		}

		dlog_print(DLOG_FATAL, LOG_TAG, "close");

//		1. --
//		pthread_exit(0);

// 		2. --
//		h.sync_close();
//		h.clear_con_listeners();

	}
}
