import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';
import 'package:udp/udp.dart';
import 'package:mutex/mutex.dart';

class HeartbeatServer {
  final String id;
  int time;
  HeartbeatServer(this.id, this.time);
}

class Server {
  String name;
  final String id;
  List<HeartbeatServer> servers = [];
  final ServerSocket socketServer;
  ClientToServer client_found;
  final m = ReadWriteMutex();
  //lista que é preechida com arquivos enviados pelos multicasts somente com arquivos
  List<String> filesToSend = [];
  //dados de cada usuario no supernodo inclui seu identificador e arquivos
  List<ClientToServer> clients_info = [];
  Server(this.name, this.socketServer, this.id);

  void handleConnectionSupernodo(Datagram data) async {
    //validar para lidar com string ou objetos que pode ser enviados
    if (data != null) {
      final object = String.fromCharCodes(data.data);
      Map<String, dynamic> decodedMessage = jsonDecode(object);
      final messageObject =
          MessageClient(decodedMessage['message'], decodedMessage['data']);

      switch (messageObject.message) {
        case 'JOIN':
          {
            if (messageObject.data != null) {
              print('JOIN SERVER message');
              final String idData = messageObject.data;
              final time = 0;
              var heartbeatServer = HeartbeatServer(idData, time);
              final hasData = await hasServer(idData);
              if (!hasData) {
                addServer(heartbeatServer);
                final message = MessageClient('PRESENT_IN_NETWORK', id);
                await sendPackageToMulticast(message);
              }
            }
          }
          break;

        case 'PRESENT_IN_NETWORK':
          {
            if (messageObject.data != null) {
              print('PRESENT_IN_NETWORK SERVER message');
              final String idData = messageObject.data;
              final time = 0;
              var heartbeatServer = HeartbeatServer(idData, time);
              final hasData = await hasServer(idData);
              if (!hasData) {
                addServer(heartbeatServer);
              }
            }
          }
          break;

        case 'HEARTBEAT_SERVER':
          {
            if (messageObject.data != null) {
              final String idData = messageObject.data;
              print('HeartBeat server come from $idData');
              resetTimeToServer(idData);
            }
          }
          break;

        case 'REQUEST_FILES_PEERS':
          {
            //incrementa o valor pois alguem respondeu e envia como  array via multicast
            //todos seus arquivos somente filename
            print('REQUEST_FILES_PEERS SERVER message');
            final file = await getFiles();
            final message = MessageClient('RESPONSE_FILES', file);
            await sendPackageToMulticast(message);
          }
          break;

        case 'RESPONSE_FILES':
          {
            //todos seus arquivos somente nome do arquivo
            if (messageObject.data != null) {
              print('RESPONSE_FILES SERVER message');
              final files = messageObject.data.cast<String>();
              addFilesFromSupernodo(files);
            }
          }
          break;

        case 'WHO_HAVE_THIS_FILE':
          {
            if (messageObject.data != null) {
              print('WHO_HAVE_THIS_FILE SERVER message');
              final hashFile = messageObject.data;
              final client = await getClientFromFile(hashFile);
              if (client != null) {
                final clientSend = ClientToServer(client.id, client.ip,
                    client.availablePort, [messageObject.data], 0);
                final message = MessageClient('GET_FILE', clientSend);
                await sendPackageToMulticast(message);
              }
            }
          }
          break;
        case 'GET_FILE':
          {
            if (messageObject.data != null) {
              print('GET_FILE SERVER message');
              //ja passamos somente 1 hash
              var list = messageObject.data['files'].cast<String>();
              final clientObject = ClientToServer(
                  messageObject.data['id'],
                  messageObject.data['ip'],
                  messageObject.data['availablePort'],
                  list,
                  0);
              client_found = clientObject;
            }
          }
          break;
        default:
          {
            print('Mensagem nao mapeada');
          }
          break;
      }
    }
  }

  void handleConnectionNodo(Socket client) {
    print('Connection from'
        ' ${client.remoteAddress.address}:${client.remotePort}');
    client.listen(
      (Uint8List data) async {
        final object = String.fromCharCodes(data);
        Map<String, dynamic> decodedMessage = jsonDecode(object);
        final messageObject =
            MessageClient(decodedMessage['message'], decodedMessage['data']);
        switch (messageObject.message) {
          case 'REQUEST_LIST_FILES':
            {
              print('REQUEST LIST FILES message');
              final list = await getServers();
              if (list.length > 1) {
                final message = MessageClient('REQUEST_FILES_PEERS', []);
                await sendPackageToMulticast(message);
                //manda processar a thead para responder depois
                processRequestFiles(client);
                //manda mensagem que recebeu a solicitacao
                final messageWithFile = MessageClient('PROCESSING_REQUEST', []);
                var encodedMessage = jsonEncode(messageWithFile);
                client.write(encodedMessage);
              } else {
                //mandar minha propria lista de arquivos nome dos arquivos
                final list = await getFiles();
                final message = MessageClient('RESPONSE_LIST', list);
                var encodedMessage = jsonEncode(message);
                client.write(encodedMessage);
              }
            }
            break;

          case 'JOIN':
            {
              if (messageObject.data != null) {
                print('JOIN MESSAGE');
                print("files ${messageObject.data['files']}");
                List<FileHash> filehashList = [];
                final list = messageObject.data['files'];
                for (var i = 0; i < list.length; i++) {
                  var hash = FileHash(list[i]['filename'], list[i]['hash']);
                  print("Cheguei no hash ${hash.fileName} ${hash.hash}");
                  filehashList.add(hash);
                }
                final clientObject = ClientToServer(
                    messageObject.data['id'],
                    messageObject.data['ip'],
                    messageObject.data['availablePort'],
                    filehashList,
                    0);
                print("Lista de files $filehashList");
                await addNodo(clientObject);
                final message = MessageClient('REGISTER', []);
                var encodedMessage = jsonEncode(message);
                print(encodedMessage);
                client.write(encodedMessage);
              }
            }
            break;

          case 'REQUEST_PEER':
            {
              if (messageObject.data != null) {
                print('REQUEST_PEER MESSAGE');
                //vamos receber um nome de um arquivo aqui precisamos converter
                final hashFromFile =
                    await convertNameFileToHash(messageObject.data);

                if (hashFromFile != null) {
                  final hasClient = await getClientFromFile(hashFromFile);
                  if (hasClient == null) {
                    final message =
                        MessageClient('WHO_HAVE_THIS_FILE', hashFromFile);
                    await sendPackageToMulticast(message);
                    //manda processar a thead para responder depois
                    processRequestClient(client);
                    //manda mensagem que recebeu a solicitacao
                    final messageWithFile =
                        MessageClient('PROCESSING_REQUEST', []);
                    var encodedMessage = jsonEncode(messageWithFile);
                    client.write(encodedMessage);
                  } else {
                    //O arquivo estava na minha lista
                    final dynamic hashFile = FileHash("",hashFromFile);
                    final clientSend = ClientToServer(hasClient.id,
                        hasClient.ip, hasClient.availablePort, [hashFile], 0);
                    final message =
                        MessageClient('RESPONSE_CLIENT_WITH_DATA', clientSend);
                    var encodedMessage = jsonEncode(message);
                    client.write(encodedMessage);
                  }
                }
              }
            }
            break;

          case 'HEARTBEAT_CLIENT':
            {
              if (messageObject.data != null) {
                print('HEARTBEAT_CLIENT MESSAGE');
                final String idData = messageObject.data;
                print('HeartBeat Client come from $idData');
                resetTimeToClients(idData);
              }
            }
            break;

          default:
            {
              client.write(
                  'Nada encontrado com essa solicitacao: ${messageObject.data}');
            }
            break;
        }
      },

      // handle errors
      onError: (error) {
        print(error);
      },

      // handle the client closing the connection
      onDone: () {
        print('Conexao encerrada nodo caiu');
      },
    );
  }

  Future<List<String>> getFiles() async {
    await m.acquireRead();
    try {
      // ignore: omit_local_variable_types
      List<String> files = [];
      for (var i = 0; i < clients_info.length; i++) {
        var client = clients_info[i];
        for (var j = 0; j < client.files.length; j++) {
          // para mandar para o usuario utiliza somente o filename
          //para mandar para o servidor ou algum request tem que o usar o hash
          files.add(client.files[j].fileName);
        }
      }
      return files;
    } finally {
      m.release();
    }
  }

  void processRequestFiles(Socket client) async {
    //por enquanto assumimos que em 6 segundos vai responder todo mundo na rede
    await Future.delayed(Duration(seconds: 6));
    final list = await sendFiles();
    final messageWithFile = MessageClient('RESPONSE_LIST', list);
    var encodedMessage = jsonEncode(messageWithFile);
    try {
      client.write(encodedMessage);
    } finally {
      await resetListOfFilesFromSupernodo();
    }
  }

  void processRequestClient(Socket client) async {
    //por enquanto assumimos que em 6 segundos vai responder todo mundo na rede
    await Future.delayed(Duration(seconds: 6));
    final list = client_found;
    final messageWithFile = MessageClient('RESPONSE_CLIENT_WITH_DATA', list);
    var encodedMessage = jsonEncode(messageWithFile);
    try {
      client.write(encodedMessage);
    } finally {
      print('Kaputz!');
    }
  }

  Future<List<String>> sendFiles() async {
    await m.acquireRead();
    try {
      // ista de arquivos nome dos arquivos
      // ignore: omit_local_variable_types
      List<String> files = await filesToSend;
      return files;
    } finally {
      m.release();
    }
  }

  void listenerMulticast() async {
    // MULTICAST
    var multicastEndpoint =
        Endpoint.multicast(InternetAddress('239.1.2.3'), port: Port(54321));
    var receiver = await UDP.bind(multicastEndpoint);

    await receiver.listen((datagram) {
      if (datagram != null) {
        handleConnectionSupernodo(datagram);
      }
    });
  }

  void listenerServerSocket() async {
    await socketServer.listen((client) {
      handleConnectionNodo(client);
    });
  }

  Future<void> sendPackageToMulticast(MessageClient messageClient) async {
    var multicastEndpoint =
        Endpoint.multicast(InternetAddress('239.1.2.3'), port: Port(54321));
    var sender = await UDP.bind(Endpoint.any());
    var encodedMessage = jsonEncode(messageClient);
    await sender.send(encodedMessage.codeUnits, multicastEndpoint);
  }

  void addNodo(ClientToServer client) async {
    await m.acquireWrite();
    try {
      // sessao critica
      if (clients_info.isEmpty) {
        clients_info.add(client);
      } else {
        if (!clients_info.contains(client)) {
          clients_info.add(client);
        }
      }
    } finally {
      m.release();
    }
  }

  void addFilesFromSupernodo(List<String> file) async {
    await m.acquireWrite();
    try {
      // sessao critica
      filesToSend.addAll(file);
    } finally {
      m.release();
    }
  }

  void resetListOfFilesFromSupernodo() async {
    await m.acquireWrite();
    try {
      // sessao critica
      filesToSend.clear();
    } finally {
      m.release();
    }
  }

  Future<ClientToServer> getClientFromFile(String hash) async {
    await m.acquireRead();
    try {
      for (var i = 0; i < clients_info.length; i++) {
        var client = clients_info[i];
        for (var j = 0; j < client.files.length; j++) {
          if (hash == client.files[j].hash) {
            return client;
          }
        }
      }
      return null;
    } finally {
      m.release();
    }
  }

  Future<String> convertNameFileToHash(String fileName) async {
    await m.acquireRead();
    try {
      for (var i = 0; i < clients_info.length; i++) {
        var client = clients_info[i];
        for (var j = 0; j < client.files.length; j++) {
          if (fileName == client.files[j].fileName) {
            return client.files[j].hash;
          }
        }
      }
      return null;
    } finally {
      m.release();
    }
  }

  Future<bool> hasClient(String id) async {
    await m.acquireRead();
    try {
      for (var i = 0; i < clients_info.length; i++) {
        if (clients_info[i].id == id) {
          return true;
        }
      }
      return false;
    } finally {
      m.release();
    }
  }

  Future<List<ClientToServer>> getClients() async {
    await m.acquireRead();
    try {
      return clients_info;
    } finally {
      m.release();
    }
  }

  void resetTimeToClients(String id) async {
    await m.acquireWrite();
    try {
      final lst = clients_info;
      if (lst.isNotEmpty && id.isNotEmpty) {
        for (var i = 0; i < lst.length; i++) {
          if (lst[i].id == id) {
            lst[i].time = 0;
          }
        }
      }
    } finally {
      m.release();
    }
  }

  void removeClients() async {
    await m.acquireWrite();
    try {
      final lst = clients_info;
      if (lst.isNotEmpty) {
        final size = lst.length;
        for (var i = 0; i < size; i++) {
          if (lst[i].time > 3) {
            lst.remove(lst[i]);
          }
        }
      }
    } finally {
      m.release();
    }
  }

  void incrementTimeClients() async {
    await m.acquireWrite();
    try {
      final lst = clients_info;
      if (lst.isNotEmpty) {
        for (var i = 0; i < lst.length; i++) {
          lst[i].time++;
        }
      }
    } finally {
      m.release();
    }
  }

  Future<bool> hasServer(String id) async {
    await m.acquireRead();
    try {
      for (var i = 0; i < servers.length; i++) {
        if (servers[i].id == id) {
          return true;
        }
      }
      return false;
    } finally {
      m.release();
    }
  }

  Future<List<HeartbeatServer>> getServers() async {
    await m.acquireRead();
    try {
      return servers;
    } finally {
      m.release();
    }
  }

  void resetTimeToServer(String id) async {
    await m.acquireWrite();
    try {
      if (servers.isNotEmpty) {
        for (var i = 0; i < servers.length; i++) {
          if (servers[i].id == id) {
            servers[i].time = 0;
          }
        }
      }
    } finally {
      m.release();
    }
  }

  void removeServers() async {
    await m.acquireWrite();
    try {
      if (servers.isNotEmpty) {
        final size = servers.length;
        for (var i = 0; i < size; i++) {
          if (servers[i].time > 3) {
            servers.remove(servers[i]);
          }
        }
      }
    } finally {
      m.release();
    }
  }

  void incrementServers() async {
    await m.acquireWrite();
    try {
      if (servers.isNotEmpty) {
        for (var i = 0; i < servers.length; i++) {
          servers[i].time++;
        }
      }
    } finally {
      m.release();
    }
  }

  void addServer(HeartbeatServer server) async {
    await m.acquireWrite();
    try {
      // sessao critica
      if (servers.isEmpty) {
        servers.add(server);
      } else {
        if (!servers.contains(server)) {
          servers.add(server);
        }
      }
    } finally {
      m.release();
    }
  }

  void removeServer(String server) async {
    await m.acquireWrite();
    try {
      // sessao critica
      if (servers.isNotEmpty) {
        servers.remove(server);
      }
    } finally {
      m.release();
    }
  }

  void heartbeatServer() async {
    const fiveSec = Duration(seconds: 5);
    Timer.periodic(
        fiveSec,
        (Timer t) =>
            sendPackageToMulticast(MessageClient('HEARTBEAT_SERVER', id)));
  }

  void incrementTimeServer() async {
    const fiveSec = Duration(seconds: 5);
    Timer.periodic(fiveSec, (Timer t) => incrementServers());
  }

  void removeServeWithNoResponse() async {
    const sec = Duration(seconds: 15);
    Timer.periodic(sec, (Timer t) => removeServers());
  }

  void incrementTimeToClients() async {
    const fiveSec = Duration(seconds: 5);
    Timer.periodic(fiveSec, (Timer t) => incrementTimeClients());
  }

  void removeClientsWithNoResponse() async {
    const sec = Duration(seconds: 15);
    Timer.periodic(sec, (Timer t) => removeClients());
  }
}
