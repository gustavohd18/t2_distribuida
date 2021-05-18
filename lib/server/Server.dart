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

class Server {
  String name;
  int total_supernodo = 0;
  int current_total_supernodo = 0;
  final ServerSocket socketServer;
  List<Socket> clients = [];
  final m = ReadWriteMutex();
  //lista que é preechida com arquivos enviados pelos multicasts somente com arquivos
  //e o identificador do client para solicitacao dos  demais dados no caso de dowload
  HashMap<String, List<String>> peersFilesFromSuperNodos = HashMap();
  //dados de cada usuario no supernodo inclui seu identificador e arquivos
  List<ClientToServer> clients_info = [];
  Server(this.name, this.socketServer);

  void handleConnectionSupernodo(Datagram data) {
    //validar para lidar com string ou objetos que pode ser enviados
    final message = String.fromCharCodes(data.data);
    print('datagrama vindo ${message}');
    switch (message) {
      case 'JOIN':
        {
          incrementTotalSupernodo();
        }
        break;

      case 'REQUEST_FILES_PEERS':
        {
          //incrementa o valor pois alguem respondeu e envia como  array via multicast
          //todos seus arquivos
          incrementCurrentSupernodos();
        }
        break;

      default:
        {
          print('Mensagem nao mapeada');
        }
        break;
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
                await sendPackageToMulticast('REQUEST_FILES_PEERS');
                //fazer outras coisas TODO
                //await espera todos responderem
                print('data enviado do nodo ${messageObject.data}');
                client.write('Mandei a lista de geral');
              } else {
                //mandar minha propria lista de arquivos
                final list = await getFiles();
                final message = MessageClient('RESPONSE_LIST', list);
                var encodedMessage = jsonEncode(message);
                print(encodedMessage);
               // client.write(encodedMessage);
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
              print('data enviado do nodo ${messageObject.data['files']}');
              await addNodo(clientObject);
              final message = MessageClient('REGISTER', []);
              var encodedMessage = jsonEncode(message);
              print(encodedMessage);
              client.write(encodedMessage);
            }
            break;

          case 'REQUEST_PEER':
            {
              client.write('Solicitacao de peers atendidas');
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

  List<String> getFiles() {
    //adicionar mutex para pegar da lista
    // ignore: omit_local_variable_types
    List<String> files = [];
    for (var i = 0; i < clients_info.length; i++) {
      var client = clients_info[i];
      for (var j = 0; j < client.files.length; j++) {
        files.add(client.files[j]);
      }
    }

    return files;
  }

  Future<void> listenerMulticast() async {
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

  Future<void> listenerServerSocket() async {
    await socketServer.listen((client) {
      handleConnectionNodo(client);
      //precisa validar se existe o client ou nao na lista de clients para caso nao exista adicionar o mesmo
      //precisa cuidar mutex ou semaforo
      addClient(client);
    });
  }

  Future<void> sendPackageToMulticast(String message) async {
    var multicastEndpoint =
        Endpoint.multicast(InternetAddress('239.1.2.3'), port: Port(54321));
    var sender = await UDP.bind(Endpoint.any());
    await sender.send(message.codeUnits, multicastEndpoint);
  }

  void addClient(Socket client) {
    //adicionar semaforo ou mutex aqui
    if (clients.isEmpty) {
      print('Adicionei o socket do primeiro nodo');
      clients.add(client);
    } else {
      if (!clients.contains(client)) {
        print('Adicionei o socket do nodo');
        clients.add(client);
      }
    }
  }

  void addNodo(ClientToServer client) async {
    print("client $client");
    await m.acquireWrite();
    // No other locks (read or write) can be acquired until released
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
      print('Algum supernodo respondeu');
      current_total_supernodo++;
    } finally {
      m.release();
    }
  }

  void decrementCurrentSupernodos() async {
    await m.acquireWrite();
    try {
      // sessao critica
      print('todos supernodos responderam');
      current_total_supernodo = 0;
    } finally {
      m.release();
    }
  }
}
