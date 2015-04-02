/**
 * Copyright Francis kim.
 */
var ENUMS = require('./enums');
var logger = require('./logger');
var sqlite = require('./sql/default');

var path = require('path');
var HashMap = require('hashmap').HashMap;
var socketIo = require('socket.io');

var CudaRender = require('./cuda/render').CudaRender;
var cu = require('./cuda/load');
var cuCtx = new cu.Ctx(0, cu.Device(0));

logger.debug(cu.deviceCount);

var cuDevice = new cu.Device(0);
logger.debug(cuDevice);

var Android = require('./event/android').Android;
var Web = require('./event/web').Web;

/**
 * Nornejs server create 
 * @param server
 *  HttpCreateServer 
 * @constructor
 *  SET max conection client, cuda ptx path, cuda data path;
 */
var NornenjsServer = function(server){
    this.MAX_CONNECTION_CLIENT = 10;

    this.CUDA_PTX_PATH = path.join(__dirname, '../src-cuda/volume.ptx');
    this.CUDA_DATA_PATH = path.join(__dirname, './data/');

    this.server = server;
    this.io = socketIo.listen(this.server);
    this.cudaRenderMap = new HashMap();
    
    //TODO 해당되는 클라이언트가 무엇인지에 따라서 사용되는 socket event Handler를 다르게 한다.
    this.android = new Android(this.cudaRenderMap);
    this.web = new Web(this.cudaRenderMap);

    //TODO Redis Server Exec And set hash key



    //var httpProxy = require('http-proxy');
    //httpProxy.createProxyServer({target:'http://112.108.40.166:5000'}).listen(8000);
};

// ~ PROXY SERVER
// TODO STEP 01. NornenjsServer 가 작동하게 되면 내가 ROOT 라면 Proxy 서버와 Redis를 실행한다.
// TODO STEP 02. CUDA Graphic Card Device를 조회하여
// TODO          " GRAPHIC_HOST(key) " : IP_DEVICE_NUMBER "
// TODO          " IP_DEVICE_NUMBER(key) : 0(value) " 로 하여 Redis에 저장한다.

// ~ OTHER SERVER
// TODO STEP 01. NornenjsServer 연결시 Proxy 사용 여부를 선택하고 해당되는 Proxy를 선택한다면 Root 인지 선택하고 ROOT가 아니라면 Proxy 서버 IP를 작성한다.
// TODO STEP 02. Proxy 사용하면서 서버가 아니라면 Redis 클라이언트를 연결한다.
// TODO STEP 03. CUDA Graphic Card Device를 조회하여
// TODO          " GRAPHIC_HOST(key) " : IP_DEVICE_NUMBER "
// TODO          " IP_DEVICE(key) : 0(value) " 로 하여 Redis에 저장한다.

// 사용자 접속
// TODO STEP 01. 해당 접속은 무조건 ROOT PROXY 에서만 접근이 가능하도록 해야한다.
// TODO STEP 02. GRAPHIC_HOST(key) 를 통하여 IP DEVICE 를 가져온뒤 해당 키값에 대한 Min 값을 찾고 Min 값에 따라서 Device를 연결해주도록 한다.

/**
 * Nornensjs server create
 */
NornenjsServer.prototype.connect = function(){
    this.socketIoConnect();

    var redis = require("redis"),
        client = redis.createClient(6379, '112.108.40.166', {});

    client.on('error', function (err) {
        logger.error('Error', err);
    });

    client.set("string key", "string val", redis.print);
    client.hset("hash key", "hashtest 1", "some value", redis.print);
    client.hset(["hash key", "hashtest 2", "some other value"], redis.print);
    client.hkeys("hash key", function (err, replies) {
        console.log(replies.length + " replies:");
        replies.forEach(function (reply, i) {
            console.log("    " + i + ": " + reply);
        });
    });
    client.quit();

};

/**
 * Socket Io First Connect
 */
NornenjsServer.prototype.socketIoConnect = function(){

    var $this = this;
    var clientQueue = [];
    var streamClientCount = 0;

    this.io.sockets.on('connection', function(socket){
        
        $this.android.addSocketEventListener(socket);
        $this.web.addSocketEventListener(socket);
        
        /**
         * Connection User
         * TODO 사용자 관리는 프록시 서버가 되는 부분으로 이전될 예정
         */
        socket.on('connectMessage', function(){

            var clientId = socket.id;

            var message = {
                error : '',
                success : false,
                clientId : clientId
            };

            if(streamClientCount < $this.MAX_CONNECTION_CLIENT){
                streamClientCount++;
                message.success = true;
            }else{
                clientQueue.push(clientId);
                message.error = 'Visitor limit';
            }

            logger.debug('[Connect] Stream user count [' + streamClientCount + ']');
            logger.debug('Send message client id [' + clientId + ']');

            socket.emit('connectMessage', message);
        });

        /**
         * Disconnection User - Wait queue client connect request
         */
        socket.on('disconnect', function () {
            
            var clientId = socket.id;
            
            if(clientQueue.indexOf(clientId) == -1){
                streamClientCount--;
                logger.debug('[Disconnect] Stream user count [' + streamClientCount + ']');
                logger.debug('Disconnect socket client id ['+ clientId +']');
            }

            var connectClientId = clientQueue.shift();

            if(connectClientId != undefined){
                logger.debug('Connect socket client id [' + connectClientId + ']');
                socket.broadcast.to(connectClientId).emit('otherClientDisconnect');
            }

        });


        /**
         * Init cudaRenderObject
         */
        socket.on('init', function(){

            var volumePn = 1;
            var clientId = socket.id;

            sqlite.db.get(sqlite.sql.volume.selectVolumeOne, { $pn: volumePn }, function(err, volume){

                logger.debug('[Stream] volume object ', volume);

                if(volume == undefined) {
                    logger.error('[Stream] Fail select volume data');
                    // TODO Announce fail lode volume data to client
                    return;
                }else {
                    logger.debug('[Stream] Register CUDA module ');

                    var cudaRender = new CudaRender(
                                            ENUMS.RENDERING_TYPE.VOLUME, $this.CUDA_DATA_PATH + volume.save_name,
                                            volume.width, volume.height, volume.depth,
                                            cuCtx, cu.moduleLoad($this.CUDA_PTX_PATH));
                    cudaRender.init();
                    
                    $this.cudaRenderMap.set(clientId, cudaRender);
                    socket.emit('loadCudaMemory');
                }
            });
        });

    });

};

module.exports.NornenjsServer = NornenjsServer;
