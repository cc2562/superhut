import 'package:enhanced_future_builder/enhanced_future_builder.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:superhut/pages/hutpages/hutmainLogic.dart';
import 'package:superhut/pages/hutpages/type1/type1webview.dart';
import 'package:superhut/pages/hutpages/type2/type2webview.dart';
import 'package:superhut/utils/hut_user_api.dart';

class HutMainPage extends StatefulWidget {
  const HutMainPage({super.key});

  @override
  State<HutMainPage> createState() => _HutMainPageState();
}

class _HutMainPageState extends State<HutMainPage> with WidgetsBindingObserver {
  final api = HutUserApi();
  final logic = Get.put(HutMainLogic());
  final state = Get.find<HutMainLogic>().state;

  // Controller for search field
  final TextEditingController _searchController = TextEditingController();

  // State for search text
  String _searchText = '';

  // Focus node for the search field
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    logic.checkLogin();
    // Register as observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Add listener to search controller
    _searchController.addListener(() {
      setState(() {
        _searchText = _searchController.text;
      });
    });

    // Ensure no automatic focus when the page loads
    _searchFocusNode.addListener(() {
      // Debug focus changes if needed
      //print("Search focus: ${_searchFocusNode.hasFocus}");
    });
  }

  @override
  void dispose() {
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);

    // Clean up controllers and focus nodes
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is resumed, unfocus to prevent keyboard from showing
    if (state == AppLifecycleState.resumed) {
      _unfocusSearchField();
    }
  }

  // Method to clear focus when needed
  void _unfocusSearchField() {
    if (_searchFocusNode.hasFocus) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Add a listener to the route to detect when this page is navigated to
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Unfocus when the build is complete (which happens when returning to the page)
      _unfocusSearchField();
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text("智慧工大"), elevation: 0),
      body: GestureDetector(
        // Unfocus when tapping outside of the text field
        onTap: _unfocusSearchField,
        child: SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    autofocus: false,
                    controller: _searchController,
                    //focusNode: _searchFocusNode,
                    decoration: InputDecoration(
                      filled: false,
                      hintText: '搜索...',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon:
                          _searchText.isNotEmpty
                              ? IconButton(
                                icon: Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                              : null,
                      border: InputBorder.none,

                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),

              // Function list
              Expanded(
                child: EnhancedFutureBuilder(
                  future: logic.getFunList(),
                  rememberFutureResult: true,
                  whenDone: (v) {
                    // Collect all services across all categories for search
                    List<Map<String, dynamic>> allServicesWithCategory = [];

                    for (var category in v) {
                      List<FunctionItem> services = category['services'];
                      String categoryLabel = category['label'];

                      for (var service in services) {
                        if (service.id != "8aaa866184af29a50185527fddf70dac" &&
                            service.id != "8aaa84f692e5ae560193f24790e76752" &&
                            service.serviceType != "4") {
                          allServicesWithCategory.add({
                            'service': service,
                            'category': categoryLabel,
                          });
                        }
                      }
                    }

                    // If searching, show filtered results
                    if (_searchText.isNotEmpty) {
                      List<Map<String, dynamic>> filteredServices =
                          allServicesWithCategory
                              .where(
                                (item) =>
                                    item['service'].serviceName
                                        .toLowerCase()
                                        .contains(_searchText.toLowerCase()) ||
                                    item['category'].toLowerCase().contains(
                                      _searchText.toLowerCase(),
                                    ),
                              )
                              .toList();

                      if (filteredServices.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '未找到与"$_searchText"相关的功能',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: filteredServices.length,
                        itemBuilder: (context, index) {
                          FunctionItem service =
                              filteredServices[index]['service'];
                          String category = filteredServices[index]['category'];

                          return Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show category as a small label
                                if (index == 0 ||
                                    filteredServices[index]['category'] !=
                                        filteredServices[index - 1]['category'])
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: 8,
                                      top: index > 0 ? 16 : 0,
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                _buildServiceCard(
                                  serviceName: service.serviceName,
                                  serviceType: service.serviceType,
                                  onTap: () {
                                    if (service.serviceType == "1") {
                                      Get.to(
                                        Type1Webview(
                                          serviceUrl: service.serviceUrl,
                                          serviceName: service.serviceName,
                                        ),
                                      );
                                    } else if (service.serviceType == "2") {
                                      Get.to(
                                        Type2Webview(
                                          serviceUrl: service.serviceUrl,
                                          serviceName: service.serviceName,
                                          tokenAccept: service.tokenAccept,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    // If not searching, show original categorized list
                    return ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: v.length,
                      itemBuilder: (context, index) {
                        List<FunctionItem> services = v[index]['services'];
                        // Filter out services we don't want to show
                        List<FunctionItem> filteredServices =
                            services
                                .where(
                                  (service) =>
                                      service.id !=
                                          "8aaa866184af29a50185527fddf70dac" &&
                                      service.id !=
                                          "8aaa84f692e5ae560193f24790e76752",
                                )
                                .toList();

                        // If no services in this category after filtering, don't show the category
                        if (filteredServices.isEmpty) {
                          return SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category title
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 16,
                                top: index > 0 ? 24 : 0,
                              ),
                              child: Text(
                                v[index]['label'],
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Services in this category
                            ...filteredServices
                                .map(
                                  (service) => Padding(
                                    padding: EdgeInsets.only(bottom: 16),
                                    child: _buildServiceCard(
                                      serviceName: service.serviceName,
                                      serviceType: service.serviceType,
                                      onTap: () {
                                        if (service.serviceType == "1") {
                                          Get.to(
                                            Type1Webview(
                                              serviceUrl: service.serviceUrl,
                                              serviceName: service.serviceName,
                                            ),
                                          );
                                        } else if (service.serviceType == "2" ||
                                            service.serviceType == "4") {
                                          Get.to(
                                            Type2Webview(
                                              serviceUrl: service.serviceUrl,
                                              serviceName: service.serviceName,
                                              tokenAccept: service.tokenAccept,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        );
                      },
                    );
                  },
                  whenNotDone: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Custom card widget similar to _buildActivityCard in FunctionPage
  Widget _buildServiceCard({
    required String serviceName,
    required String serviceType,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow icon
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle),
                padding: EdgeInsets.all(8),
                child: Icon(Icons.arrow_forward, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
