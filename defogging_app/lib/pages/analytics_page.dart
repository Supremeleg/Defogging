import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int selectedTab = 0; // 0: Lessons, 1: Card Meanings
  int selectedCard = -1; // Currently selected card index
  String searchText = '';

  final List<_CardItem> cards = [
    _CardItem('GBLND', 'City of London'),
    _CardItem('GBWSM', 'Westminster'),
    _CardItem('GBKEC', 'Kensington and Chelsea'),
    _CardItem('GBHMF', 'Hammersmith and Fulham'),
    _CardItem('GBWND', 'Wandsworth'),
    _CardItem('GBLBH', 'Lambeth'),
    _CardItem('GBSWK', 'Southwark'),
    _CardItem('GBTWH', 'Tower Hamlets'),
    _CardItem('GBHCK', 'Hackney'),
    _CardItem('GBISL', 'Islington'),
    _CardItem('GBCMD', 'Camden'),
    _CardItem('GBBEN', 'Brent'),
    _CardItem('GBEAL', 'Ealing'),
    _CardItem('GBHNS', 'Hounslow'),
    _CardItem('GBRIC', 'Richmond upon Thames'),
    _CardItem('GBKTT', 'Kingston upon Thames'),
    _CardItem('GBMRT', 'Merton'),
    _CardItem('GBSTN', 'Sutton'),
    _CardItem('GBCRY', 'Croydon'),
    _CardItem('GBBRY', 'Bromley'),
    _CardItem('GBLEW', 'Lewisham'),
    _CardItem('GBGRE', 'Greenwich'),
    _CardItem('GBBEX', 'Bexley'),
    _CardItem('GBHAV', 'Havering'),
    _CardItem('GBBDG', 'Barking and Dagenham'),
    _CardItem('GBRDB', 'Redbridge'),
    _CardItem('GBNWM', 'Newham'),
    _CardItem('GBWFT', 'Waltham Forest'),
    _CardItem('GBHRY', 'Haringey'),
    _CardItem('GBENF', 'Enfield'),
    _CardItem('GBBNE', 'Barnet'),
    _CardItem('GBHRW', 'Harrow'),
    _CardItem('GBHIL', 'Hillingdon'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 80),
                  _buildTabBar(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        final card = cards[index];
                        final isSelected = selectedCard == index;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCard = index;
                            });
                          },
                          onDoubleTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CardDetailPage(
                                  svgName: card.svgName,
                                  displayName: card.displayName,
                                ),
                              ),
                            );
                          },
                          child: _buildCard(card, isSelected),
                        );
                      },
                    ),
                  ),
                ],
              ),
              // Gradient overlay
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color.fromRGBO(0, 0, 0, 0.5), // 50% black at bottom
                          Color.fromRGBO(0, 0, 0, 0.0), // Transparent at top
                        ],
                        stops: [0.0, 0.25], // Gradient to 25% from top is fully transparent
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          _buildTabButton('Lessons', 0),
          _buildTabButton('Card Meanings', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final bool isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.search, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ace of Swords',
                hintStyle: TextStyle(color: Colors.white54),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  searchText = value;
                });
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic, color: Colors.white70),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () {
              setState(() {
                searchText = '';
              });
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(_CardItem card, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: ListTile(
        leading: SvgPicture.asset(
          'assets/London/${card.svgName}.svg',
          width: 36,
          height: 36,
          color: isSelected ? Colors.black : Colors.white,
        ),
        title: Text(
          card.displayName,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w400,
            fontSize: 18,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: 0.0,
                backgroundColor: isSelected ? Colors.black12 : Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(isSelected ? Colors.black : Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '0/0',
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: Icon(Icons.more_vert, color: isSelected ? Colors.black : Colors.white),
      ),
    );
  }
}

class _CardItem {
  final String svgName;
  final String displayName;
  _CardItem(this.svgName, this.displayName);
}

class CardDetailPage extends StatelessWidget {
  final String svgName;
  final String displayName;
  const CardDetailPage({super.key, required this.svgName, required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow
                      Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.6),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      // SVG发光层（形状与SVG一致，带高斯模糊和透明度）
                      Opacity(
                        opacity: 0.7,
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: SvgPicture.asset(
                            'assets/London/$svgName.svg',
                            width: 128,
                            height: 128,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // 白色细轮廓
                      SvgPicture.asset(
                        'assets/London/$svgName.svg',
                        width: 128,
                        height: 128,
                        color: Colors.white,
                      ),
                      // 主体
                      SvgPicture.asset(
                        'assets/London/$svgName.svg',
                        width: 120,
                        height: 120,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    displayName,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w400, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 64,
            left: 12,
            child: ClipOval(
              child: Material(
                color: Colors.black.withOpacity(0.08), // 轻微透明背景
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 