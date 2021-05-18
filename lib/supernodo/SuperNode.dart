import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:collection';
import 'package:udp/udp.dart';

import 'Messages.dart';

class SuperNode {
  String name;
  final ServerSocket socketServer;
  List<Socket> clients = [];
  HashMap<String, String> peersFiles = HashMap();
  HashMap<String, String> peersFilesFromSuperNodos = HashMap();
  SuperNode(this.name, this.socketServer);

  void handleConnectionSupernodo(Datagram data) {
    print('Cheguei no  handle do supernodo');
    print('datagrama vindo ${data.data}');
  }

  void handleConnectionNodo(Socket client) {
    print('Connection from'
        ' ${client.remoteAddress.address}:${client.remotePort}');

    client.listen(
      (Uint8List data) async {
        final message = String.fromCharCodes(data);
        switch (message) {
          case 'REQUEST_LIST_FILES':
            {
              await sendPackageToMulticast('REQUEST_FILES_PEERS');
              client.write('Solicitacao de arquivos atendidas');
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
              client.write('Nada encontrado com essa solicitacao: ${message}');
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
      print('Adicionei o primeiro nodo');
      clients.add(client);
    } else {
      if (!clients.contains(clients)) {
        print('adicionei depois');
        clients.add(client);
      }
    }
  }
}
