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
  // ### FILE HASH ### //
  final clientFilesList = await client.getHash(patch);
  for (String s in clientFilesList) {
    print(s);
  }

  final clientData = ClientToServer(
      client.id, client.ip, client.availablePort, clientFilesList, 0);

  final messageDataClient = MessageClient('JOIN', clientData);

  await client.sendMessageStringToSupernodo(messageDataClient);
  client.heartbeatClient();
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
    if (args.length < 4) {
      print(
          'Formato [<nodo> <porta do supernodo> <ip do supernodo> <path dos files>]');
      return;
    }

    final socket = await Socket.connect(args[2], port);
    // precisa adicionar parametro por linha de comando para o id e o proprio ip e propria porta disponivel
    final files = <String>['disneyorrenr', 'netflixfilmetorren'];
    final client = Client('same4', socket, '0.0.0.0', 8089);
    client.listenerSupernodo();
    //dispara a future para lidar com a leitura dos arquivos
    sendFilesToServerFromClient(client, args[3]);
    terminalInteractive(client);
  }
}
