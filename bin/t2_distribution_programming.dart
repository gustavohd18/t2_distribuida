import 'dart:typed_data';
import 'package:udp/udp.dart';
import 'package:t2_distribution_programming/supernodo/SuperNode.dart';
import 'package:t2_distribution_programming/t2_distribution_programming.dart'
    as t2_distribution_programming;
/*
   Multicast UDP broadcaster
   multicast_send.dart
*/
import 'dart:io';
import 'dart:async';
import 'dart:math';

Future<void> receivePackageMulticast(SuperNode supernode) async {
  // MULTICAST
  var multicastEndpoint =
      Endpoint.multicast(InternetAddress("239.1.2.3"), port: Port(54321));
  var receiver = await UDP.bind(multicastEndpoint);

    await receiver.listen((datagram) {
      if (datagram != null) {
      supernode.handleConnectionSupernodo(datagram);
      }
    });
}

//nodo
Future<void> sendMessage(Socket socket, String message) async {
  print('Client: $message');
  socket.write(message);
  await Future.delayed(Duration(seconds: 2));
}

void main(List<String> args) async {
  if (args.length < 2) {
    print('Formato [<nodo ou supernodo> <porta>]');
    return;
  }

  final port = int.parse(args[1]);

  if (args[0] == 'supernodo') {
    final ip = InternetAddress.anyIPv4;
    final server = await ServerSocket.bind(ip, port);
    var supernode = SuperNode(ip.address);
    print('Supernodo ip $ip e porta $port');
    server.listen((client) {
      supernode.handleConnectionNodo(client);
    });

    await receivePackageMulticast(supernode);
  } else if (args[0] == 'nodo') {
    if (args.length < 3) {
      print(
          'Formato [<nodo ou supernodo> <porta mesma do supernodo> <ip do supernodo> <path dos files>]');
      return;
    }

    // connect to the socket server
    final socket = await Socket.connect(args[2], port);
    print('Connected to: ${socket.remoteAddress.address}:${socket.remotePort}');

    // listen for responses from the server
    socket.listen(
      // handle data from the server
      (Uint8List data) {
        final serverResponse = String.fromCharCodes(data);
        print('Server: $serverResponse');
      },

      // handle errors
      onError: (error) {
        print(error);
        socket.destroy();
      },

      // handle server ending connection
      onDone: () {
        print('Server left.');
        socket.destroy();
      },
    );
    await sendMessage(socket, 'REQUEST_LIST_FILES');
  }
  //tipo node ou supernodo, porta sempre tem que passar indiferente se for tipo node tem que validar o ip para se conectar com o supernodo

//  await sendPackage();
  // await receivePackage();
}
