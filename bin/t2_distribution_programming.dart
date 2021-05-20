import 'package:t2_distribution_programming/ClientToServer.dart';
import 'package:t2_distribution_programming/client/Client.dart';
import 'package:t2_distribution_programming/client/MessageClient.dart';
import 'package:t2_distribution_programming/server/Server.dart';
import 'dart:io';

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
    // ### FILE HASH ### //
    final clientFilesList = await client.getHash(args[3]);
    for (String s in clientFilesList) {
      print(s);
    }
    //exemplo envio dos dados do client
    final clientData =
        ClientToServer(client.id, client.ip, client.availablePort, files, 0);

    final messageDataClient = MessageClient('JOIN', clientData);

    await client.sendMessageStringToSupernodo(messageDataClient);
    client.heartbeatClient();
    //exemplo por enquanto envia um request mas isso estara num listener
    final messageExample = MessageClient('REQUEST_LIST_FILES', []);
    await client.sendMessageStringToSupernodo(messageExample);
    final messageData = MessageClient('REQUEST_PEER', 'disneytorrent');
    await Future.delayed(Duration(seconds: 30));
    await client.sendMessageStringToSupernodo(messageData);
  }
}
