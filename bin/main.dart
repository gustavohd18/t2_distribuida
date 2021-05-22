import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:t2_distribution_programming/client/Client.dart';
import 'package:t2_distribution_programming/data/ClientToServer.dart';
import 'package:t2_distribution_programming/data/Message.dart';
import 'package:t2_distribution_programming/server/Server.dart';
import 'dart:io';

Future<ReceivePort> initIsolate() async {
  var isolateToMainStream = ReceivePort();

  await Isolate.spawn(terminalIsolate, isolateToMainStream.sendPort);
  return isolateToMainStream;
}

// function which run in a Thread to handle with interactive from user
void terminalIsolate(SendPort isolateToMainStream) {
  while (true) {
    print('=======================');
    print('Bem vindo ao FileLand');
    print('1: Visualizar arquivos disponivel para download');
    print('2: solicitar download(Precisa passar o nome do arquivo)');
    print('=======================');
    var line = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
    var option = 0;
    try {
      option = int.parse(line.trim());
    } catch(e) {
      option = 0;
    }
    switch (option) {
      case 1:
        {
          isolateToMainStream.send(1);
        }
        break;
      case 2:
        {
          print('Informe o nome do arquivo:');
          var line = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
          var file = line;
          isolateToMainStream.send(file);
        }
        break;
      default:
        {
          print('Dado não mapeado');
        }
        break;
    }
  }
}

void sendFilesToServerFromClient(Client client, String path) async {
  print('Processando o mapeamento da pasta informada');
  // ###  call function which handle HASH ### //
  final clientFilesList = await client.getHash(path);

  final clientData = ClientToServer(
      client.id, client.ip, client.availablePort, clientFilesList, 0);

  final messageDataClient = Message('JOIN', clientData);

  await client.sendMessageStringToSupernodo(messageDataClient);
  client.heartbeatClient();
  print('Mapeamento encerrado com sucesso');
}

void main(List<String> args) async {
  if (args.length < 3) {
    print('Formato [<nodo ou supernodo> <porta> <id>]');
    return;
  }

  final interfaces = await NetworkInterface.list(
    includeLinkLocal: true,
    type: InternetAddressType.IPv4,
    includeLoopback: true,
  );

  final interface = interfaces[1];
  final port = int.parse(args[1]);

  if (args[0] == 'supernodo') {
    final id = args[2];
    final ip = interface.addresses[0];
    final server = await ServerSocket.bind(ip, port);
    var supernode = Server(ip.address, server, id);

    print('Supernodo ip: $ip porta: $port id:$id');

    // call all functions which will handle with clients and other servers
    supernode.listenerServerSocket();
    supernode.listenerMulticast();
    supernode.heartbeatServer();
    supernode.incrementTimeServer();
    supernode.removeServeWithNoResponse();
    supernode.incrementTimeToClients();
    supernode.removeClientsWithNoResponse();

    //send message multicast to join
    final message = Message('JOIN', id);
    await supernode.sendPackageToMulticast(message);
  } else if (args[0] == 'nodo') {
    if (args.length < 7) {
      print(
          'Formato [<nodo> <porta do supernodo> <ip do supernodo> <porta disponivel> <id> <path dos arquivos> <path para  salvar os arquivos>]');
      return;
    }

    final socket = await Socket.connect(args[2], port);
    final id = args[4];
    final ip = interface.addresses[0];
    final portFree = int.parse(args[3]);
    final pathToSaveFiles = args[6];
    final serverToReceiveFiles = await ServerSocket.bind(ip, portFree);
    final client = Client(id, socket, ip.address, portFree,
        serverToReceiveFiles, pathToSaveFiles);

    // call functions to handle with server, request from other clients and read folder,
    // to do hash
    client.listenerSupernodo();
    client.listenerToDownload();
    sendFilesToServerFromClient(client, args[5]);

    var mainToIsolateStream = await initIsolate();
    mainToIsolateStream.listen((message) async {
      switch (message) {
        case 1:
          {
            final messageRequest = Message('REQUEST_LIST_FILES', []);
            await client.sendMessageStringToSupernodo(messageRequest);
          }
          break;
        default:
          final messageData = Message('REQUEST_PEER', message);
          await client.sendMessageStringToSupernodo(messageData);
      }
    });
  }
}
