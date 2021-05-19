import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:collection';
import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';
import 'package:udp/udp.dart';
import 'package:mutex/mutex.dart';
import 'Messages.dart';

class HeartbeatServer {
  final String id;
  int time;
  HeartbeatServer(this.id, this.time);
}

class Server {
  String name;
  final String id;
  List<HeartbeatServer> servers = [];
  int total_supernodo = 0;
  int current_total_supernodo = 0;
  final ServerSocket socketServer;
  List<Socket> clients = [];
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
          break;

        case 'PRESENT_IN_NETWORK':
          {
            final String idData = messageObject.data;
            final time = 0;
            var heartbeatServer = HeartbeatServer(idData, time);
            final hasData = await hasServer(idData);
            if (!hasData) {
              addServer(heartbeatServer);
            }
          }
          break;

        case 'HEARTBEAT_SERVER':
          {
            final String idData = messageObject.data;
            resetTimeToServer(idData);
          }
          break;

        case 'REQUEST_FILES_PEERS':
          {
            //incrementa o valor pois alguem respondeu e envia como  array via multicast
            //todos seus arquivos
            final file = await getFiles();
            final message = MessageClient('RESPONSE_FILES', file);
            await sendPackageToMulticast(message);
          }
          break;

        case 'RESPONSE_FILES':
          {
            //incrementa o valor pois alguem respondeu e envia como  array via multicast
            //todos seus arquivos
            final files = messageObject.data.cast<String>();
            await addFilesFromSupernodo(files);
            final message = MessageClient('INCREMENT_CURRENT', []);
            await sendPackageToMulticast(message);
          }
          break;

        case 'INCREMENT_CURRENT':
          {
            print('INCREMENT');
            await incrementCurrentSupernodos();
          }
          break;
        case 'RESET_CURRENT':
          {
            //reseta o valor dos current
            await resetCurrentSupernodos();
          }
          break;

        case 'WHO_HAVE_THIS_FILE':
          {
            final nameFile = messageObject.data;
            final client = await getClientFromFile(nameFile);
            if (client != null) {
              final message = MessageClient('GET_FILE', client);
              await sendPackageToMulticast(message);
            }
          }
          break;
        case 'GET_FILE':
          {
            //revisitar isso para deixar melhor
            var list = messageObject.data['files'].cast<String>();
            final clientObject = ClientToServer(
              messageObject.data['id'],
              messageObject.data['ip'],
              messageObject.data['availablePort'],
              list,
            );
            client_found = clientObject;
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
              //nao tem só 1 supernodo na rede
              if (total_supernodo > 1) {
                final message = MessageClient('REQUEST_FILES_PEERS', []);
                await sendPackageToMulticast(message);
                //manda processar a thead para responder depois
                processRequestFiles(client);
                //manda mensagem que recebeu a solicitacao
                final messageWithFile = MessageClient('PROCESSING_REQUEST', []);
                var encodedMessage = jsonEncode(messageWithFile);
                client.write(encodedMessage);
              } else {
                //mandar minha propria lista de arquivos
                final list = await getFiles();
                final message = MessageClient('RESPONSE_LIST', list);
                var encodedMessage = jsonEncode(message);
                client.write(encodedMessage);
              }
            }
            break;

          case 'JOIN':
            {
              //adiciona client para a lista de client converter os dados
              //precisa realizar o cast
              final list = messageObject.data['files'].cast<String>();
              final clientObject = ClientToServer(
                messageObject.data['id'],
                messageObject.data['ip'],
                messageObject.data['availablePort'],
                list,
              );
              await addNodo(clientObject);
              final message = MessageClient('REGISTER', []);
              var encodedMessage = jsonEncode(message);
              print(encodedMessage);
              client.write(encodedMessage);
            }
            break;

          case 'REQUEST_PEER':
            {
              //nao tem só 1 supernodo na rede
              final hasClient = await getClientFromFile(messageObject.data);
              if (hasClient == null) {
                final message =
                    MessageClient('WHO_HAVE_THIS_FILE', messageObject.data);
                await sendPackageToMulticast(message);
                //manda processar a thead para responder depois
                processRequestClient(client);
                //manda mensagem que recebeu a solicitacao
                // final messageWithFile = MessageClient('PROCESSING_REQUEST', []);
                // var encodedMessage = jsonEncode(messageWithFile);
                //client.write(encodedMessage);
              } else {
                //O arquivo estava na minha pasta
                final message =
                    MessageClient('RESPONSE_CLIENT_WITH_DATA', hasClient);
                var encodedMessage = jsonEncode(message);
                client.write(encodedMessage);
              }
            }
            break;

          case 'SEND_FILES_LIST':
            {
              client.write('Solicitacao de arquivos atendidas');
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
        client.close();
      },

      // handle the client closing the connection
      onDone: () {
        print('Conexao encerrada supernodo caiu');
        client.close();
      },
    );
  }

  Future<List<String>> getFiles() async {
    //adicionar mutex para pegar da lista
    await m.acquireRead();
    try {
      // ignore: omit_local_variable_types
      List<String> files = [];
      for (var i = 0; i < clients_info.length; i++) {
        var client = clients_info[i];
        for (var j = 0; j < client.files.length; j++) {
          files.add(client.files[j]);
        }
      }
      return files;
    } finally {
      m.release();
    }
  }

  void processRequestFiles(Socket client) async {
    //preciso validar aqui se todos os nodos enviaram algo ou passar x tempo envia o que tem
    //por enquanto assumimos que em 10 segundos vai responder todo mundo na rede
    await Future.delayed(Duration(seconds: 10));
    final list = await sendFiles();
    final messageWithFile = MessageClient('RESPONSE_LIST', list);
    var encodedMessage = jsonEncode(messageWithFile);
    client.write(encodedMessage);
  }

  void processRequestClient(Socket client) async {
    await Future.delayed(Duration(seconds: 10));
    final list = client_found;
    final messageWithFile = MessageClient('RESPONSE_CLIENT_WITH_DATA', list);
    var encodedMessage = jsonEncode(messageWithFile);
    client.write(encodedMessage);
  }

  Future<List<String>> sendFiles() async {
    //adicionar mutex para pegar da lista
    await m.acquireRead();
    try {
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
      addClient(client);
    });
  }

  Future<void> sendPackageToMulticast(MessageClient messageClient) async {
    var multicastEndpoint =
        Endpoint.multicast(InternetAddress('239.1.2.3'), port: Port(54321));
    var sender = await UDP.bind(Endpoint.any());
    var encodedMessage = jsonEncode(messageClient);
    await sender.send(encodedMessage.codeUnits, multicastEndpoint);
  }

  void addClient(Socket client) async {
    //adicionar semaforo ou mutex aqui
    await m.acquireWrite();
    // No other locks (read or write) can be acquired until released
    try {
      // sessao critica
      if (clients.isEmpty) {
        print('Adicionei o socket do primeiro nodo');
        clients.add(client);
      } else {
        if (!clients.contains(client)) {
          print('Adicionei o socket do nodo');
          clients.add(client);
        }
      }
    } finally {
      m.release();
    }
  }

  void addNodo(ClientToServer client) async {
    await m.acquireWrite();
    try {
      // sessao critica
      if (clients_info.isEmpty) {
        print('Adicionei os dados do primeiro nodo');
        clients_info.add(client);
      } else {
        if (!clients_info.contains(client)) {
          print('Adicionei os dados do nodo');
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

  void incrementTotalSupernodo() async {
    await m.acquireWrite();
    try {
      // sessao critica
      print('novo supernodo na rede');
      total_supernodo++;
    } finally {
      m.release();
    }
  }

  void decrementTotalSupernodo() async {
    await m.acquireWrite();
    try {
      // sessao critica
      print('menos supernodo na rede');
      total_supernodo--;
    } finally {
      m.release();
    }
  }

  void incrementCurrentSupernodos() async {
    await m.acquireWrite();
    try {
      // sessao critica
      current_total_supernodo++;
    } finally {
      m.release();
    }
  }

  void resetCurrentSupernodos() async {
    await m.acquireWrite();
    try {
      // sessao critica
      print('todos supernodos responderam');
      current_total_supernodo = 0;
    } finally {
      m.release();
    }
  }

  void checkUpdate() async {
    //adicionar mutex para pegar da lista
    await m.acquireWrite();
    try {
      //tryTenSegs++;
      final current = await getCurrentTotalSupernodo();
      final total = await getTotalSupernodos();

      if (current_total_supernodo >= total_supernodo) {
        //  canSend = true;
        // tryTenSegs = 0;
      }
    } finally {
      m.release();
    }
  }

  void resetListOfFilesFromSupernodo() async {
    await m.acquireWrite();
    try {
      // sessao critica
      filesToSend = [];
    } finally {
      m.release();
    }
  }

  Future<int> getCurrentTotalSupernodo() async {
    await m.acquireRead();
    try {
      return current_total_supernodo;
    } finally {
      m.release();
    }
  }

  Future<int> getTotalSupernodos() async {
    await m.acquireRead();
    try {
      return total_supernodo;
    } finally {
      m.release();
    }
  }

  Future<ClientToServer> getClientFromFile(String file) async {
    await m.acquireRead();
    try {
      for (var i = 0; i < clients_info.length; i++) {
        var client = clients_info[i];
        for (var j = 0; j < client.files.length; j++) {
          if (file == client.files[j]) {
            return client;
          }
        }
      }
      return null;
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
          servers[i].time = 0;
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
          if (servers[i].time > 4) {
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
    const fiveSec = Duration(seconds: 10);
    Timer.periodic(fiveSec, (Timer t) => incrementServers());
  }

  void removeServeWithNoResponse() async {
    const fiveSec = Duration(seconds: 15);
    Timer.periodic(fiveSec, (Timer t) => removeServers());
  }
}
