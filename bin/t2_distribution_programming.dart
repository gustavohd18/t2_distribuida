import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/Client.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';
import 'package:t2_distribution_programming/server/Server.dart';
import 'dart:io';

Future<ReceivePort> initIsolate() async {
  Completer completer = new Completer<SendPort>();
  var isolateToMainStream = ReceivePort();


  var myIsolateInstance =
      await Isolate.spawn(myIsolate, isolateToMainStream.sendPort);
  return isolateToMainStream;
}

void myIsolate(SendPort isolateToMainStream) {
  while (true) {
    print('=======================');
    print('Bem vindo ao FilesLand');
    print('1: Visualizar arquivos disponivel para download');
    print('2: solicitar download(Precisa passar o nome do arquivo)');
    print('=======================');
    var line = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
    var option = int.parse(line.trim());
    switch (option) {
      case 1:
        {
          isolateToMainStream.send(1);
        }
        break;
      case 2:
        {
          //precisa mapear para de  alguma forma mandar o arquivo que escolheu  seja via option ou algo  assim
          //provavelmente armazenar em uma lista todos os recebidos na lib client
          print('Informe o nome do arquivo:');
          var line = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
          var file = line;
          isolateToMainStream.send(file);
        }
        break;
      default:
        {
          print('Valor não mapeado');
        }
        break;
    }
  }
}

void sendFilesToServerFromClient(Client client, String patch) async {
  print('Processando o mapeamento da pasta informada');
  // ### FILE HASH ### //
  final clientFilesList = await client.getHash(patch);

  final clientData = ClientToServer(
      client.id, client.ip, client.availablePort, clientFilesList, 0);

  final messageDataClient = MessageClient('JOIN', clientData);

  await client.sendMessageStringToSupernodo(messageDataClient);
  client.heartbeatClient();
  print('Mapeamento encerrado');
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
    supernode.listenerServerSocket();
    supernode.listenerMulticast();
    supernode.heartbeatServer();
    supernode.incrementTimeServer();
    supernode.removeServeWithNoResponse();
    supernode.incrementTimeToClients();
    supernode.removeClientsWithNoResponse();
    // sempre que um supernodo entra na rede ele envia uma msg do tipo join
    final message = MessageClient('JOIN', id);
    await supernode.sendPackageToMulticast(message);
  } else if (args[0] == 'nodo') {
    if (args.length < 7) {
      print(
          'Formato [<nodo> <porta do supernodo> <ip do supernodo> <porta disponivel> <id> <path dos arquivos> <path para  salvar os arquivos>]');
      return;
    }

    final socket = await Socket.connect(args[2], port);
    // precisa adicionar parametro por linha de comando para o id e o proprio ip e propria porta disponivel
    final id = args[4];
    final ip = interface.addresses[0];
    final portFree = int.parse(args[3]);
    final pathToSaveFiles = args[6];
    final serverToReceiveFiles = await ServerSocket.bind(ip, portFree);
    final client = Client(id, socket, ip.address, portFree,
        serverToReceiveFiles, pathToSaveFiles);
    client.listenerSupernodo();
    client.listenerToDownload();
    //dispara a future para lidar com a leitura dos arquivos
    sendFilesToServerFromClient(client, args[5]);

    var mainToIsolateStream = await initIsolate();
    mainToIsolateStream.listen((message) async {
      switch (message) {
          case 1:
            {
              final messageRequest = MessageClient('REQUEST_LIST_FILES', []);
              await client.sendMessageStringToSupernodo(messageRequest);
            }
            break;
          default:
            final messageData = MessageClient('REQUEST_PEER', message);
            await client.sendMessageStringToSupernodo(messageData);
        }
    });
  }
}
