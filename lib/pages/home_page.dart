import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/post_model.dart';
import '../widgets/post_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late List<Post> _dummyPosts;

  @override
  void initState() {
    super.initState();
    _dummyPosts = _getDummyPosts();
  }

  List<Post> _getDummyPosts() {
    return [
      Post(
        id: '1',
        username: 'Maija Retkeilijä',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=1',
        postImageUrl: 'https://picsum.photos/seed/trail1/600/400',
        caption:
            'Amazing day hike at Teijo National Park! Trails were in great condition and the views were breathtaking. 🌲☀️ #hiking #nature #teijo',
        timestamp:
            DateTime.now().subtract(const Duration(hours: 2, minutes: 35)),
        likes: 125,
        comments: 18,
        location: 'Teijo National Park',
      ),
      Post(
        id: '2',
        username: 'Erkki Eräilijä',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=2',
        postImageUrl: 'https://picsum.photos/seed/mountain2/600/400',
        caption:
            'Weekend adventure at Koli. It was windy at the top, but the views made it all worth it! Highly recommended. #koli #nationalview #hiking #finland',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
        likes: 210,
        comments: 32,
        location: 'Koli National Park',
      ),
      Post(
        id: '3',
        username: 'Laura Luontokuvaaja',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=3',
        caption:
            'Short evening walk in the local forest. The silence and fresh air are so good for you. Small joys in everyday life. 😌 #forest #naturetherapy #eveningwalk',
        timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 12)),
        likes: 95,
        comments: 12,
        location: 'Kauppi Sports Park, Tampere',
      ),
      Post(
        id: '4',
        username: 'Petteri PolunTallaaja',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=4',
        postImageUrl: 'https://picsum.photos/seed/aurora4/600/400',
        caption:
            'Northern lights hunting in Inari last night was magical! Cold, but definitely worth it. ✨🌌 #aurora #lapland #inarijarvi #nightSky',
        timestamp: DateTime.now().subtract(const Duration(hours: 10)),
        likes: 302,
        comments: 45,
        location: 'Inari, Lapland',
      ),
      Post(
        id: '5',
        username: 'Sini Sääksjärvi',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=5',
        postImageUrl: 'https://picsum.photos/seed/lake5/600/400',
        caption:
            'Beautiful morning at Sääksjärvi! Kayaking at sunrise is the best. 🌅🛶 #kayaking #sunrise #lakelandscape',
        timestamp: DateTime.now().subtract(const Duration(hours: 4)),
        likes: 180,
        comments: 20,
        location: 'Sääksjärvi',
      ),
      Post(
        id: '6',
        username: 'Ville Vaeltaja',
        userAvatarUrl: 'https://i.pravatar.cc/150?img=6',
        postImageUrl: 'https://picsum.photos/seed/forest6/600/400',
        caption:
            'Long hike in the Korouoma canyon done. The ice falls were amazing! 💪❄️ #korouoma #icefall #winterhike',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        likes: 250,
        comments: 38,
        location: 'Korouoma Canyon',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: () {
            authProvider.logout();
          },
        ),
        title: Hero(
          tag: 'appLogo',
          child: Image.asset(
            'assets/images/white2.png',
            height: 80,
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search posts',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Search functionality is not implemented yet.'),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          setState(() {
            _dummyPosts = _getDummyPosts()..shuffle();
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Posts "refreshed" (order shuffled).'),
            ),
          );
        },
        color: theme.colorScheme.secondary,
        backgroundColor: theme.primaryColor,
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 8.0, bottom: 80.0),
          itemCount: _dummyPosts.length,
          itemBuilder: (context, index) {
            return PostCard(post: _dummyPosts[index]);
          },
          separatorBuilder: (context, index) => const SizedBox(height: 16.0),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adding a new post/note is not implemented yet.'),
            ),
          );
        },
        tooltip: 'Add post or note',
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text("Add post"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
