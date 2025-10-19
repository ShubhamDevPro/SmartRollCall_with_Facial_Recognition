import 'package:flutter/material.dart';
import 'person.dart';
import 'main.dart';

// ignore: must_be_immutable
class PersonView extends StatefulWidget {
  final List<Person> personList;
  final MyHomePageState homePageState;

  const PersonView(
      {super.key, required this.personList, required this.homePageState});

  @override
  _PersonViewState createState() => _PersonViewState();
}

class _PersonViewState extends State<PersonView> {
  deletePerson(int index) async {
    await widget.homePageState.deletePerson(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        itemCount: widget.personList.length,
        itemBuilder: (BuildContext context, int index) {
          return SizedBox(
              height: 60,
              child: Card(
                  child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                  ),
                  const Icon(
                    Icons.person,
                    size: 40,
                  ),
                  const SizedBox(
                    width: 16,
                  ),
                  Text(widget.personList[index].name),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => deletePerson(index),
                  ),
                  const SizedBox(
                    width: 8,
                  )
                ],
              )));
        });
  }
}
