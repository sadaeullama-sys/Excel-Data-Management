import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const FinderApp());

class FinderApp extends StatelessWidget {
  const FinderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Excel Data Finder',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff12366b)), useMaterial3: true),
    home: const LoginPage(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final user = TextEditingController(text: 'admin');
  final pass = TextEditingController(text: '1234');
  String error = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SingleChildScrollView(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(margin: const EdgeInsets.all(24), child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.table_view, size: 64, color: Color(0xff168447)),
          const Text('Excel Data Finder', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('Franchise Manager • Demo'),
          const SizedBox(height: 20),
          TextField(controller: user, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person))),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock))),
          if (error.isNotEmpty) Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(onPressed: () {
            if (user.text.trim() == 'admin' && pass.text == '1234') {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
            } else { setState(() => error = 'Invalid login. Demo: admin / 1234'); }
          }, child: const Text('Login / لاگ اِن')),
          const Text('Demo login: admin / 1234', style: TextStyle(color: Colors.grey)),
        ]),
      )),
    ))),
  );
}

class RecordRow {
  final String file;
  final int rowNumber;
  final Map<String, String> cells;
  RecordRow(this.file, this.rowNumber, this.cells);
  Map<String, dynamic> toJson() => {'file': file, 'row': rowNumber, 'cells': cells};
  factory RecordRow.fromJson(Map<String, dynamic> j) => RecordRow(j['file'] ?? '', j['row'] ?? 0, Map<String,String>.from(j['cells'] ?? {}));
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override State<DashboardPage> createState() => _DashboardPageState();
}
class _DashboardPageState extends State<DashboardPage> {
  final query = TextEditingController();
  List<RecordRow> records = [];
  List<RecordRow> results = [];
  List<String> files = [];
  bool loading = false;
  String status = 'Upload Excel files to begin.';
  @override void initState() { super.initState(); loadSaved(); }
  Future<void> loadSaved() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('records');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List;
      setState(() { records = decoded.map((e) => RecordRow.fromJson(Map<String,dynamic>.from(e))).toList(); files = records.map((e)=>e.file).toSet().toList(); status = 'Saved local data loaded.'; });
    }
  }
  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('records', jsonEncode(records.map((e)=>e.toJson()).toList()));
  }
  String normalize(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
  bool isPhoneHeader(String h) {
    final x=h.toLowerCase();
    return x.contains('mobile') || x.contains('phone') || x.contains('number') || x.contains('موبائل') || x.contains('فون') || x.contains('نمبر');
  }
  bool isCnicHeader(String h) {
    final x=h.toLowerCase().replaceAll(' ', '');
    return x.contains('cnic') || x.contains('شناختی') || x.contains('شناخت') || x.contains('identity');
  }
  Future<void> importExcel() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx'], allowMultiple: true, withData: true);
    if (picked == null) return;
    setState(() { loading=true; status='Importing Excel...'; });
    int added=0;
    for (final f in picked.files) {
      if (f.bytes == null) continue;
      try {
        final book=Excel.decodeBytes(f.bytes!);
        final current=<RecordRow>[];
        for (final sheet in book.tables.values) {
          if (sheet.rows.isEmpty) continue;
          final headers=sheet.rows.first.map((c)=>c?.value?.toString().trim() ?? '').toList();
          for (int i=1; i<sheet.rows.length; i++) {
            final row=sheet.rows[i];
            final map=<String,String>{};
            for (int c=0;c<headers.length;c++) {
              final key=headers[c].isEmpty ? 'Column ${c+1}' : headers[c];
              final value=c<row.length ? row[c]?.value?.toString().trim() ?? '' : '';
              if (value.isNotEmpty) map[key]=value;
            }
            if (map.isNotEmpty) current.add(RecordRow(f.name, i+1, map));
          }
        }
        // Avoid adding the same filename repeatedly; importing it again replaces its old rows.
        records.removeWhere((r)=>r.file==f.name);
        records.addAll(current);
        added += current.length;
        if (!files.contains(f.name)) files.add(f.name);
      } catch (_) { status='Could not read ${f.name}. Please check it is a valid .xlsx file.'; }
    }
    await persist();
    setState(() { loading=false; results=[]; status='Import complete. Added/updated $added rows.'; });
  }
  void search() {
    final q=query.text.trim();
    if (q.isEmpty) { setState(()=>results=[]); return; }
    final nq=normalize(q);
    setState(() {
      results=records.where((r) {
        final entries=r.cells.entries;
        // Search phone/CNIC values based on header, then fallback to all cells so varied Excel headings still work.
        final focused=entries.where((e)=>isPhoneHeader(e.key)||isCnicHeader(e.key)).toList();
        final values=focused.isNotEmpty ? focused.map((e)=>e.value) : entries.map((e)=>e.value);
        return values.any((v) => (normalize(v).isNotEmpty && normalize(v).contains(nq)) || v.toLowerCase().contains(q.toLowerCase()));
      }).toList();
    });
  }
  @override Widget build(BuildContext context) {
    final theme=Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Excel Data Finder • Demo'), backgroundColor: const Color(0xff12366b), foregroundColor: Colors.white, actions:[IconButton(onPressed:importExcel, icon:const Icon(Icons.upload_file), tooltip:'Upload Excel')]),
      body: ListView(padding: const EdgeInsets.all(16), children:[
        Wrap(spacing:10, runSpacing:10, children:[
          metric('Excel Files',files.length.toString(),Colors.blue),
          metric('Total Records',records.length.toString(),Colors.green),
          metric('Search Results',results.length.toString(),Colors.deepPurple),
        ]),
        const SizedBox(height:16),
        Card(child: Padding(padding:const EdgeInsets.all(16), child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
          const Text('Search by Mobile Number OR CNIC / موبائل نمبر یا CNIC', style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
          const SizedBox(height:12),
          TextField(controller:query, keyboardType:TextInputType.text, onSubmitted:(_)=>search(), decoration:InputDecoration(hintText:'Enter mobile number or CNIC', prefixIcon:const Icon(Icons.search), border:const OutlineInputBorder(), suffixIcon:IconButton(icon:const Icon(Icons.clear),onPressed:(){query.clear();setState(()=>results=[]);}))),
          const SizedBox(height:10),
          SizedBox(width:double.infinity, child:FilledButton.icon(onPressed:search, icon:const Icon(Icons.search), label:const Text('Search / تلاش کریں'))),
          Text(status, style:theme.textTheme.bodySmall),
        ]))),
        const SizedBox(height:10),
        Row(children:[Expanded(child:Text('Matching Records (${results.length})',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold))),TextButton.icon(onPressed:importExcel,icon:const Icon(Icons.add),label:const Text('Add Excel'))]),
        if(results.isEmpty) const Card(child:Padding(padding:EdgeInsets.all(20),child:Text('No results yet. Upload Excel files and search by mobile number or CNIC.'))),
        ...results.map((r)=>Card(margin:const EdgeInsets.only(bottom:10),child:ExpansionTile(title:Text(r.cells.values.take(2).join(' • '),maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text('${r.file} • Row ${r.rowNumber}'),children:[Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:r.cells.entries.map((e)=>Padding(padding:const EdgeInsets.symmetric(vertical:3),child:Text('${e.key}: ${e.value}'))).toList()))]))),
        const SizedBox(height:12),
        const Text('Imported files',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),
        ...files.map((f)=>ListTile(leading:const Icon(Icons.table_chart,color:Colors.green),title:Text(f),subtitle:Text('${records.where((r)=>r.file==f).length} rows'))),
      ]),
      floatingActionButton:FloatingActionButton.extended(onPressed:loading?null:importExcel,icon:const Icon(Icons.upload_file),label:Text(loading?'Importing...':'Upload Excel')),
    );
  }
  Widget metric(String title,String value,Color color)=>Container(width:MediaQuery.of(context).size.width>600?180:null, padding:const EdgeInsets.all(14), decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(14)), child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white)),Text(value,style:const TextStyle(color:Colors.white,fontSize:25,fontWeight:FontWeight.bold))]));
}
