import 'package:amplified_flutter/amplifyconfiguration.dart';
import 'package:amplified_flutter/models/ModelProvider.dart';
import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _nameFieldController = TextEditingController();
  final TextEditingController _descriptionFieldController = TextEditingController();
  StreamSubscription<GraphQLResponse<Todo>>? subscription;
  late List<Todo> _todos;

  @override
  void initState() {
    super.initState();
    _todos = [];
    _configureAmplify();
  }
  // Amplify Plugin Init
  Future<void> _configureAmplify() async {
    final api = AmplifyAPI( modelProvider: ModelProvider.instance );
    await Amplify.addPlugin( api );
    try{ 
      await Amplify.configure( amplifyconfig );
      await queryListItems();
      subscribe();
    } on AmplifyAlreadyConfiguredException {
      print( 'Error while initializing Amplify' );
    }
  }
  // Create a Todo
  Future<void> _createTodo( String name, String description) async {
    try{
      final todo = Todo(name: name, description: description, isDone: false );
      final request = ModelMutations.create( todo );
      final response = await Amplify.API.mutate(request: request).response;
      final createdTodo = response.data;
    } on ApiException catch( error ) {
      print('CreateTodo Mutation Failed: $error');
    }
  }
  // Update a Todo
  Future<void> updatedTodo( Todo originalTodo ) async {
    final isDoneTodo = originalTodo.copyWith( isDone: !originalTodo.isDone! );
    final request = ModelMutations.update( isDoneTodo );
    final response = await Amplify.API.mutate(request: request).response;
    final updatedTodo = response.data;
    for( int i = 0; i < _todos.length; i++ ){
      if( _todos[i].id == updatedTodo!.id ) {
        _todos[i] = updatedTodo;
      }
    }
    setState(() {});
    print('Response ::::: $updatedTodo');
  }
  // List the Todos
  Future<List<Todo?>?> queryListItems() async {
    try{
      final request = ModelQueries.list( Todo.classType );
      final response = await Amplify.API.query( request: request ).response;
      final todos = response.data?.items;
      setState(() {
        _todos = todos!.cast();
      });
    } on ApiException catch( error ) {
      print('Query failed ::::: $error');
    }
    return <Todo?>[];
  } 
  // Subscription<UpdateTodo>
  void subscribe() {
    final subscriptionRequest = ModelSubscriptions.onUpdate( Todo.classType );
    final Stream<GraphQLResponse<Todo>> operation = Amplify.API.subscribe( 
      subscriptionRequest, 
      onEstablished: () => print('Subscription established')
    );
    subscription = operation.listen(
      (event) {
        print('SUBSCRIBTION EVENT DATA RECEIVED ::::: ${event.data}');
        setState(() {
          queryListItems();
        });
      },
      onError: ( Object error ) => print('Error in subscription to Stream $error')
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView(
          padding: const EdgeInsets.symmetric( vertical: 8.0 ),
          children: _todos.map(( todo ) {
            return ListTile(
              onTap: () {
                  print('tapped button');
                  updatedTodo( todo );
                },
              leading: CircleAvatar(
                child: Text( todo.name[0] ),
              ),
              title: Column(
                children: <Widget>[
                  Text( 
                    todo.name, 
                    style: !todo.isDone! ? null :const TextStyle(
                      color: Colors.black54,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    todo.description, 
                    style: !todo.isDone! ? null :const TextStyle(
                      color: Colors.black54,
                      decoration: TextDecoration.lineThrough,
                    ),
                  )
                ] 
              ),
            );
          }).toList()
        ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _displayDialog(),
        tooltip: 'Add Item',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future<void> _displayDialog() async {
    return showDialog<void>(
      context: context, 
      barrierDismissible: false,
      builder: (BuildContext context ) {
        return AlertDialog(
          title: const Text('Add a new todo item'),
          content: Column(
            children: <Widget>[
              TextField(
                controller: _nameFieldController,
                decoration: const InputDecoration( hintText:  'Title for your new todo'),
              ),
              TextField(
                controller: _descriptionFieldController,
                decoration: const InputDecoration( hintText:  'Description for your new todo'),
              ),
            ]
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                Navigator.of( context ).pop();
                setState(() {
                  _createTodo( _nameFieldController.text, _descriptionFieldController.text );
                });
              },
            )
          ],
        );
      }
    );
  }
}
