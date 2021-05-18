import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:collection';
import 'package:t2_distribution_programming/client/Client.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';
import 'package:udp/udp.dart';

import 'Messages.dart';

class Server {
  String name;
  int total_supernodo = 0;
  int current_total_supernodo = 0;
  final ServerSocket socketServer;
  List<Socket> clients = [];
  //lista que é preechida com arquivos enviados pelos multicasts somente com arquivos
  //e o identificador do client para solicitacao dos  demais dados no caso de dowload
  HashMap<String, List<String>> peersFilesFromSuperNodos = HashMap();
  //dados de cada usuario no supernodo inclui seu identificador e arquivos
  List<Client> clients_info = [];
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
              await sendPackageToMulticast('REQUEST_FILES_PEERS');
              print('data enviado do nodo ${messageObject.data}');
              client.write('Solicitacao de arquivos atendidas');
            }
            break;

          case 'JOIN':
            {
              //adiciona client para a lista de client converter os dados
              //await addNodo();
              client.write('Nodo Registrado');
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
              client.write('Nada encontrado com essa solicitacao: ${messageObject.message}');
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
      print('Adicionei o socket do primeiro nodo');
      clients.add(client);
    } else {
      if (!clients.contains(clients)) {
        print('Adicionei o socket do nodo');
        clients.add(client);
      }
    }
  }

  void addNodo(Client client) {
    //adicionar semaforo ou mutex aqui
    if (clients_info.isEmpty) {
      print('Adicionei os dados do primeiro nodo');
      clients_info.add(client);
    } else {
      if (!clients_info.contains(clients)) {
        print('Adicionei os dados do nodo');
        clients_info.add(client);
      }
    }
  }

  void incrementTotalSupernodo() {
    //adicionar semaforo ou mutex aqui
    print('novo supernodo na rede');
    total_supernodo++;
  }

  void decrementTotalSupernodo() {
    //adicionar semaforo ou mutex aqui
    print('menos supernodo na rede');
    total_supernodo--;
  }

  void incrementCurrentSupernodos() {
    //adicionar semaforo ou mutex aqui
    print('Algum supernodo respondeu');
    current_total_supernodo++;
  }

  void decrementCurrentSupernodos() {
    //adicionar semaforo ou mutex aqui
    print('todos supernodos responderam');
    current_total_supernodo--;
  }
}
