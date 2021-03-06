import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qrcode/qrcode.dart';
import 'package:restx/screens/Constants.dart';
import 'package:restx/screens/Loading.dart';

class QrScanner extends StatefulWidget {
  @override
  _QrScannerState createState() => _QrScannerState();
}

class _QrScannerState extends State<QrScanner> {
  QRCaptureController _captureController = QRCaptureController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _captureController.onCapture((data) async {
      _captureController.pause();
      setState(() {
        _isLoading = true;
      });
      try {
        var tablesRef = Firestore.instance.collection("tables");
        var tableRef = tablesRef.document(data);
        var tableData = (await tableRef.get()).data;
        if (tableData != null) {
          if (tableData["current_user"] == null) {
            var currentUserId = (await FirebaseAuth.instance.currentUser()).uid;

            var replacement =
                await clearTableIfAvailable(tablesRef, currentUserId);
            var orderId = await createEmptyOrder(currentUserId);
            await tableRef.setData(
                {"current_user": currentUserId, "order_id": orderId},
                merge: true);
            if (replacement) {
              navigatorKey.currentState.pop([]);
            } else {
              navigatorKey.currentState.pushReplacementNamed(ROUTE_USER_HOME);
            }
          } else {
            setState(() {
              _isLoading = false;
            });
            _captureController.resume();
          }
        } else {
          setState(() {
            _isLoading = false;
          });
          _captureController.resume();
        }
      } catch (e) {
        print(e);
        setState(() {
          _isLoading = false;
        });
        _captureController.resume();
      }
    });
  }

  Future<String> createEmptyOrder(String userId) async {
    var orderRef = Firestore.instance.collection("orders").document();
    await orderRef.setData({
      "user": userId,
      "plates": [],
      "waiter": null,
      "state": UNDER_SELECTION
    });
    return orderRef.documentID;
  }

  Future<bool> clearTableIfAvailable(
      CollectionReference tablesRef, String userId) async {
    var tables = (await tablesRef
            .where("current_user", isEqualTo: userId)
            .limit(1)
            .getDocuments())
        .documents;

    if (tables.length == 0) return false;

    await tablesRef
        .document(tables[0].documentID)
        .setData({"current_user": null, "order_id": null}, merge: true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isLoading
            ? Loading()
            : SizedBox(
                height: 300,
                width: 300,
                child: QRCaptureView(controller: _captureController),
              ),
      ),
    );
  }
}
