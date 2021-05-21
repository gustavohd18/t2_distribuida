import 'dart:convert';

import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/Client.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';
import 'package:t2_distribution_programming/server/Server.dart';
import 'dart:io';

void terminalInteractive(Client client) async {
  while (true) {
    print('=======================');
    print('Bem vindo ao FilesLand');
    print('1: Visualizar arquivos disponivel para download');
    print('2: solicitar download');
    print('=======================');
    var line = stdin.readLineSync(encoding: Encoding.getByName('utf-8'));
    var option = int.parse(line.trim());
    switch (option) {
      case 1:
        {
          final messageExample = MessageClient('REQUEST_LIST_FILES', []);
          await client.sendMessageStringToSupernodo(messageExample);
        }
        break;
      case 2:
        {
          //precisa mapear para de  alguma forma mandar o arquivo que escolheu  seja via option ou algo  assim
          //provavelmente armazenar em uma lista todos os recebidos na lib client
          final messageData = MessageClient('REQUEST_PEER', 'disneytorrent');
          await client.sendMessageStringToSupernodo(messageData);
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
    //exemplo de como mandar um arquivo cada client ira abrir seu servir e ao solicitar um arquivo dele
    //ira criar um socket normal o client que oslicitou para assim baixar o arquivo
    //var bytes = await new File('/Users/gustavoduarte/Desktop/files/salacleanold.pddl').readAsBytes();
    //socket.add(bytes);
    client.listenerSupernodo();
    client.listenerToDownload();
    //dispara a future para lidar com a leitura dos arquivos
    sendFilesToServerFromClient(client, args[5]);
    await Future.delayed(Duration(seconds: 8));
    final messageExample = MessageClient('REQUEST_LIST_FILES', []);
    await client.sendMessageStringToSupernodo(messageExample);
    await Future.delayed(Duration(seconds: 12));
    final messageData = MessageClient('REQUEST_PEER', '6098117170405848868c76fc081d72942711b0016c5828781b75c682c9914b75');
    await client.sendMessageStringToSupernodo(messageData);
    //pproblema com o terminal
    // terminalInteractive(client);
  }
}
