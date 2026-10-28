import 'package:flutter/material.dart';

import 'app.dart';
import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/chat_controller.dart';
import 'controllers/customer_controller.dart';
import 'controllers/mechanic_controller.dart';
import 'core/constants/app_config.dart';
import 'repositories/api/api_application_repository.dart';
import 'repositories/api/api_audit_repository.dart';
import 'repositories/api/api_auth_repository.dart';
import 'repositories/api/api_chat_repository.dart';
import 'repositories/api/api_client.dart';
import 'repositories/api/api_request_repository.dart';
import 'repositories/api/api_review_repository.dart';
import 'repositories/api/api_vehicle_repository.dart';
import 'repositories/application_repository.dart';
import 'repositories/audit_repository.dart';
import 'repositories/auth_repository.dart';
import 'repositories/chat_repository.dart';
import 'repositories/mock_application_repository.dart';
import 'repositories/mock_audit_repository.dart';
import 'repositories/mock_auth_repository.dart';
import 'repositories/mock_chat_repository.dart';
import 'repositories/mock_data_store.dart';
import 'repositories/mock_request_repository.dart';
import 'repositories/mock_review_repository.dart';
import 'repositories/mock_vehicle_repository.dart';
import 'repositories/request_repository.dart';
import 'repositories/review_repository.dart';
import 'repositories/vehicle_repository.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/job_service.dart';
import 'services/mechanic_service.dart';
import 'services/payment_service.dart';
import 'services/request_service.dart';
import 'services/review_service.dart';
import 'services/vehicle_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final AuthRepository authRepository;
  final RequestRepository requestRepository;
  final VehicleRepository vehicleRepository;
  final ChatRepository chatRepository;
  final ReviewRepository reviewRepository;
  final ApplicationRepository applicationRepository;
  final AuditRepository auditRepository;

  if (AppConfig.useMock) {
    // Run with: flutter run -d chrome --dart-define=USE_MOCK=true
    // (no backend needed, nothing is saved)
    final MockDataStore store = MockDataStore();
    authRepository = MockAuthRepository();
    requestRepository = MockRequestRepository(store);
    vehicleRepository = MockVehicleRepository(store);
    chatRepository = MockChatRepository(store);
    reviewRepository = MockReviewRepository(store);
    applicationRepository = MockApplicationRepository(store);
    auditRepository = MockAuditRepository(store);
  } else {
    // The Node.js + MongoDB backend (folder "backend").
    final ApiClient api = ApiClient();
    authRepository = ApiAuthRepository(api);
    requestRepository = ApiRequestRepository(api);
    vehicleRepository = ApiVehicleRepository(api);
    chatRepository = ApiChatRepository(api);
    reviewRepository = ApiReviewRepository(api);
    applicationRepository = ApiApplicationRepository(api);
    auditRepository = ApiAuditRepository(api);
  }

  final RequestService requestService = RequestService(requestRepository);
  final JobService jobService = JobService(requestRepository);
  final PaymentService paymentService = PaymentService(requestRepository);
  final ReviewService reviewService =
      ReviewService(requestRepository, reviewRepository);
  final MechanicService mechanicService = MechanicService(
    requestRepository,
    applicationRepository,
    authRepository,
  );
  final ChatService chatService = ChatService(chatRepository, requestRepository);

  final AuthController authController =
      AuthController(AuthService(authRepository));
  final CustomerController customerController = CustomerController(
    requestService,
    VehicleService(vehicleRepository, requestRepository),
    paymentService,
    reviewService,
    jobService,
  );
  final MechanicController mechanicController = MechanicController(
    mechanicService,
    jobService,
    requestService,
    paymentService,
    reviewService,
  );
  final ChatController chatController = ChatController(chatService);
  final AdminController adminController = AdminController(
    AdminService(
      authRepository,
      requestRepository,
      reviewRepository,
      applicationRepository,
      auditRepository,
      mechanicService,
    ),
  );

  runApp(
    FixOnWayApp(
      authController: authController,
      customerController: customerController,
      mechanicController: mechanicController,
      chatController: chatController,
      adminController: adminController,
    ),
  );
}
