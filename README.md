Chapter 1: Introduction
1.1 Purpose of the Document
The purpose of this document is to describe the Functional and technical specifications of the “AdaptEd” mobile application. It provides clear details about software requirements, system architecture, and technical constraints, ensuring that the final product aligns with the initial project objectives.
1.2 Scope of the System
This mobile application is designed to identify cognitive learning patterns through a non-diagnostic profiling system. It will process the user uploaded academic materials and their automatic restructuring into personalized formats like bullet points and audio output. Additionally, the system includes a gamified progress system with XP, levels, and badges to enhance learning retention. The system will not include formal medical diagnostic tools nor will it serve as a replacement for traditional educational institutions. 
1.3 Intended Audience
This document is intended for project supervisors, developers, and stakeholders.
1.4 Definitions and Abbreviations
ADHD: Attention Deficit Hyperactivity Disorder, a cognitive variation characterized by weak attention retention.
API: Application Programming Interface; specifically referring to the APIs such as groqAPI/Gemini used for content personalization.
Firestore: The NoSQL database used to store user profiles and gamified progress.
RAG: Retrieval-Augmented Generation; the architecture used to process and personalize uploaded content.
TTS: Text-to-Speech; the Flutter functionality used for customized learning delivery.
Chapter 2: System Overview
2.1 Problem Context
In the current context of the local education system, there is a flawed assumption that all students rely on the same learning process and retain information uniformly. This approach has been doing more harm than good in a lot of aspects. It creates a huge barrier between neurodivergent communities where students with ADHD, dyslexia, autism, and dysphoria exist. They often face a lot of unnecessary academic stress due to this fact, eventually resulting in disengagement when it comes to learning environments. They face this problem regularly when they’re confronted with text-heavy, rigid learning materials that do not accommodate their specific cognitive requirements. 
While such technologies, which can address this issue, exist, they often have limitations such as being too expensive, depending entirely on a diagnosis basis, or being heavily fragmented, and this makes the accessibility very limited.
2.2 System Objectives
The AdaptEd mobile application aims to bridge these gaps by achieving the following objectives.
Develop a user centric interface - To create a cross platform user friendly mobile application to limit overstimulation, making it easier for the neurodivergent people to operate.
Implement a diagnose free user profile - To identify the specific need of the user through a simple screening quiz, rather than requiring medical documentation.
AI Integration - To integrate AI for dynamic content creation, and using a generative AI API to restructure the uploaded study material into relevant formats automatically.
Incorporate Accessibility and Retention tools - To have interactive features like converting text to speech using FlutterTTS gamified progress tracking system to uplift the motivation to learn.

2.3 High-Level System Description

AdaptEd is an adaptive mobile learning application, powered by AI to flip the existing traditional education system.This application utilizes a retrieval-Augmented Generation and transforms the dense lecture materials to personalized formats, according to the students cognitive profile. When the user uploads study materials, this system uses the AI API and RAG architecture to transform the formats. This application is able to leverage a combination of rule based logic and large language models, and identify learning patterns to deliver tailored content. This includes features like generating audio versions for people with dyslexic learning style or point based summaries for people with ADHD learning style, in a single interactive environment. AdaptED also uses Firebase authentication to secure the process and Firestore to track the process.


2.3.1 Strategic Mapping of features to cognitive needs

Cognitive Need
Barrier
System Feature
Technical Implementation
ADHD
Information overload
Concise, colour coded bullet points
Generative AI API
Dyslexia
Reading challenges
Customized fonts, text to audio versions
FlutterTTS
Autism
Processing vague materials/content
Structured outlines with elaborated version
RAG architecture 
Dyspraxia
Movement barriers
Enlarged buttons and voice commands
Flutter UI

Table 2.1: Mapping of features to cognitive needs





2.4 User Roles and Stakeholders
Neurodivergent and Neurotypical community - They are the primary users who complete the screening, upload the learning materials and consume the personalized formats to enhance and improve their academic performance.
Academic Assessors - Faculty members who would be overlooking and analysing the project to see if it meets the coursework criteria.
Group 38 individuals - Those who are responsible for developing AdaptEd, end to end technical execution including frontend, backend logic, and integrating AI.
External target group - Individuals who have different learning needs who will be participating in the testing and debugging phase of the system. 
Chapter 3: Functional Specifications
3.1 Functional Scope
3.1.1 In-Scope Features
The AdaptEd app will implement the following core features:
Learning Trait Screening: A non-diagnostic questionnaire based on validated psychometric scales and learning preference frameworks to identify a new user’s individual learning pattern. 
AI Content Transformation: Integration with a Generative AI Service to restructure uploaded digital learning material into bullet points, summaries, or structured outlines, based on their identified learning pattern.
Multimodal Output: Text-to-speech functionality to support auditory processing preferences for users who experience friction with dense text-based content.
Customized UI Theming: Dynamic interface adjustments (fonts, spacing, colors) based on the user's trait profile.
Gamified Reinforcement: AI-generated quizzes and an XP/Badge reward system to encourage, and motivate students as well as make the learning experience enjoyable.
Cloud Storage: Secure storage for original and adapted user materials.

3.1.2 Out-of-Scope Features
The following features are currently excluded from the development:
Medical Diagnosis: The app strictly provides educational support and does not provide clinical neurodivergency diagnoses, medical advice, or therapeutic interventions.

Offline system functionality: Content adaptation requires an active internet connection to access the AI API.

LMS Integration: System does not offer direct synchronization with external platforms like Moodle or Canvas.

Handwriting Recognition: The system will not support handwritten notes. The system currently will support digital learning material only.


3.2 User Roles and Permissions
The system has 3 prospective users: 
Learner (End User): Can take the screening quiz, upload digital learning material, generate adapted content, take quizzes, and track their own progress/XP. 

Administrator (Project Team): Monitors system health, manages API usage, and maintains the database schema.

Guest: Can view the app landing page and general information but must register to use the screening or adaptation tools.





3.3 Functional Requirements
3.3.1 User Authentication and Authorization

The system shall allow users to log in using a Firebase authentication and restrict access based on user roles. Access to personalized study materials and uploaded content shall be restricted to the authenticated owner of the account. To maintain a non-diagnostic framework, users will view a mapped "Learning Persona" rather than raw clinical screening scores. Access to system analytics and prompt configurations shall be strictly restricted to system administrators.
 
3.3.2 User Management
The system shall allow users to create, update, and deactivate their accounts. Administrators shall be allowed to view users, and view the AI prompting and make necessary adjustments
3.3.3 Core System Functions
The system shall ingest text/data from uploaded documents (e.g., PDFs) and utilize an AI Service to transform the content into a format specified by the user's trait profile (e.g., summarising a dense chapter into concise, bolded key points for a distraction-prone learning profile).
3.3.4 Data Input and Validation
The system shall ensure secure authorization during user sign up and login, ensuring all necessary fields must be filled out and validated. The screening quiz shall require all mandatory questions to be answered before generating a profile.The system shall validate that uploaded files are in accessible format and do not exceed a specified size limit. The revision quizzes shall use mcq format and answers shall be validated through the system to provide feedback.


3.3.5 Data Processing
The system shall process the extracted content using pre-defined "System Prompts". These prompts will instruct the AI to act as a specialized tutor, utilizing the user’s specific learning trait to determine the output style (e.g., Structured Hierarchy for users preferring rigid order, or Conversational/Short-form for users with attention regulation challenges).

3.3.6 Data Storage and Retrieval
The system shall store the user screening results, user information  and necessary data in Firebase Firestore to ensure the user can seamlessly use the system without facing the need to re-enter basic information or redo screening processes. The data will be retrieved using RAG architecture ensuring accuracy and practicality.

3.3.7 Reporting and Outputs
The system shall allow the user to view their learning progress, as the system will report their progress through displaying their quiz scores, current XP level, and badges earned. The system will also generate system analysis reporting for the administrators to enable informed decision making. 

3.3.8 Error Handling and Notifications
The system shall have both global and custom exception handling in order to ensure a seamless user experience. For example the system shall display a "Processing Error" message if the AI fails to adapt a document, or an error stating that the file size is too large if the file uploaded is too large for the system to handle.

3.4 Use Case Overview
3.4.1 Use Case Diagram

Figure 3.1: Use Case Diagram

3.4.2 Use Case Descriptions
Use Case: Initial Trait Screening
Actor: Learner
Description: The user answers a series of questions based on screening tools.
Pre-condition: User is logged in and has not yet completed a profile.
Post-condition: The system assigns a trait profile to the user's Firestore document.
Use Case: PDF Content Adaptation
Actor: Learner / AI API
Description: User selects a document; the system extracts the text and sends it to the AI. The AI returns a version tailored to the user's profile.
Pre-condition: User has a trait profile and has uploaded a valid document.
Post-condition: The adapted text is displayed and saved to the user's library.
Use Case: Gamified Quiz Generation
Actor: Learner / AI API
Description: The AI generates multiple-choice questions from the user's adapted notes. The user earns XP based on their score.
Pre-condition: Content adaptation is complete.
Post-condition: User’s XP count is updated in Firestore.
Use Case: Access Public Information
Actor: Guest
Description: The user browses the landing page to understand the app’s features and educational philosophy without logging in.
Pre-condition: App is Accessed and opened.
Post-condition: Guests are directed to the Login/Registration screen if they attempt to access adaptation tools.
Use Case: Account Registration
Actor: Guest
Description: The user provides an email and password to create an account.
Pre-condition: Guest has selected the "Sign Up" option.
Post-condition: A new User document is created in Firebase Firestore 

Use Case: Manage User Profiles
Actor: Administrator
Description: The admin views active users and can view analytics of the system and update the database.
Pre-condition: Admin is authenticated with administrative privileges.
Post-condition: User record is updated in Firestore.

Use Case: Prompt updating
Actor: Administrator
Description: If the AI produces nonsensical or "hallucinated" content, the administrator can update or add new prompts
Pre-condition: Adaptation process is complete.
Post-condition: prompt is added or updated in system for AI to process

Chapter 4: Non-Functional Requirements
4.1 Performance Requirements
Performance requirements describe how efficiently the system would have to operate under normal and peak usage hours. Since AdaptEd is an AI-powered mobile learning application, well responsive performance is essential to prevent the core audience from being cognitively overloaded or frustrated. 
The system is expected to load within a few seconds during normal usage hours
The system shall process and display AI-adapted learning within a reasonably short time frame (depending on the complexity).
The system will support simultaneous users at once without affecting the response times of the users
The text to speech and audio playback features shall start reasonably soon and accurately after user initiation.
The application will maintain smooth navigation and transitions to ensure users have a smooth and distraction free learning experience. 

4.2 Security Requirements
Security requirements of AdaptEd defines how user data would be maintained securely by protecting sensitive information of its users like their personal details which includes usernames, passwords and other sensitive information which should be kept personal. AdaptEd would also keep uploaded materials secure and would handle personal and learning data with strong security.
The system shall authenticate users using firebase authentication.
The system will ensure that user uploaded documents and learning profiles are accessible only to the authenticated user
All data communicated within the user and the backend services would be securely implemented.
The system will comply with basic data protection policies and store only required and necessary information

4.3 Usability Requirements
Usability requirements of this application are to ensure that the system would be easy to use for any user. Given the target audience of AdaptEd it would be strictly taken into consideration to ensure the application is simple and user friendly.
The system interface will be easy to understand and easy to use for first time users
The application shall use minimalistic design to reduce cognitive overload or overstimulation
The system will produce clear icons, readable fonts and consistent layouts across all screens
The application interface would be made in a way that the user would not require external assistance to complete essential tasks




4.4 Reliability and Availability
Reliability and availability requirements define how stable and dependable the system is during an operation. A reliable system is essential in order to maintain continuous access to user learning materials.
The system will be available during standard operating hours with minimal downtime
The application will recover from minor failures without data loss
User progress, learning profiles, uploaded materials would be saved automatically across sessions 
The system will provide consistent performance on supported devices and platforms
In the event of a system failure users will not lose their personal data or progress


4.5 Scalability
The scalability requirements of this system describe the system's ability to handle future growth in user data and functionality without major redesign.
The system will support and increase in the number of total users it could handle without a discretion in its performance
The backend system shall accommodate more users at once as the user demand for the application grows
The system will support the addition of new learning features, accessibility tools and AI models in the future.
The application will be designed to accommodate increased storage requirements per user.



Chapter 5: Technical Specifications
5.1 System Architecture
5.1.1 Architectural Overview
The system follows a Three-Tier Architecture consisting of:
Presentation Layer: A cross-platform mobile interface developed using Flutter.
Application Layer: A logic-based service layer utilizing Firebase Cloud Functions and external Al APIs for content processing.
Data Layer: A structured NoSQL backend hosted on Firebase Firestore and Firebase Storage for user profiles and file persistence.

Figure 5.1: System architecture diagram
5.1.2 Component Description
The system is composed of several key components that work together to deliver personalized learning,such as:
Frontend UI : Built with Flutter to provide a neurodivergent-friendly interface that minimizes overstimulation.
AI adaptation Engine : Utilizes a generative AI API and Retrieval-Augmented Generation (RAG) architecture to restructure dense academic materials into accessible formats.
Authentication and User Management : Handled via Firebase Authentication to ensure secure user logins and profile persistence.
Accessibility Tools : Integrated modules such as FlutterTTS for text-to-speech and PDF.js for parsing uploaded documents.
5.2 Technology Stack
The technology stack was selected to provide robust accessibility support while remaining cost-effective for an undergraduate project.

Category
Technology
Purpose
Frontend
Flutter
Cross-platform UI development for Android and iOS.
Backend
Firebase
Server-side logic, hosting, and cloud functions
Data Processing
Firestore
Real time storage of user learning profiles and progress.
AI Processing
groqAI/Gemini API
Content summarization and adaptation using RAG.
Storage
Firebase Storage
Secure hosting for user-uploaded PDFs.
Accessibility
FlutterTTS/PDF.js
Native Speech to text and PDF rendering capabilities.


 




Table 5.1: Technology stack

5.3 Data Design
5.3.1 Data Model Overview
The data design is centered on creating a dynamic "Diagnosis-Free" profile for each learner. The primary entities include:
User Profile : Stores authentication data and unique neurodivergent traits identified via the initial screening quiz.
Content Metadata : Tracks uploaded PDFs, extracted text, and the subsequent AI-modified versions tailored to the user.
Gamification Data : Records experience points (XP), levels, and earned badges to maintain student motivation.

5.3.2 Database Schema
The system uses the Firebase Firestore NoSQL schema, where data is organized into collections:
User Collection : Each user is identified by a unique “User ID” from Firebase Auth.
Records Collection : This stores individual quiz results and completion statuses,which are also linked to the User (User ID).
Materials Collection : References to files stored in Firebase Storage, ensuring that processed notes are persistent across sessions.

5.4 Security Design
Security measures are integrated to protect user data and ensure ethical handling of User information.
Secure Authentication : User access is restricted through Firebase Authentication, preventing unauthorized entry to personal learning profiles.
Data Isolation : Rule-based logic within Firestore ensures that users can only read or write data associated with their own unique UserID.
Encrypted Processing : Communication with the AI API for content adaptation is conducted over secured API channels.
Privacy-First Profiling : The system uses "traits" rather than formal medical diagnoses to provide support, reducing the risks associated with storing sensitive medical records.


Chapter 6: Deployment and Environment
6.1 Hardware Requirements
For an efficient development and testing lifecycle, the following hardware requirements are required:
Development Workstation: System equipped with a minimum of 8GB RAM and 512 SSD. This is essential as the workstation will run Flutter, Android Emulators, local AL testing environments, and documentation via Chrome.
Mobile Testing: At least two physical mobile devices (an Android (API 33) and an iOS) are essential to ensure that the Text-To-Speech (TTS) is correctly validated. 
 
6.2 Software Requirements
The Following Software Stack is strictly documented to ensure version compatibility:
Framework: Flutter SDK v3.38.4(Stable Channel)
Language: Dart 3.10.3 fully utilizing null safety
Backend: Firebase Console for project orchestration, including Firestore(Database), Authentication(Security) and Cloud Functions(Logic)
AI Engine: Multi-Provider Generative AI Integration. Utilizing APIs such as Google Gemini or Groq Cloud to balance large-context document processing with high-speed interactive inference.





6.3 Network Requirements 
The Mobile App development of (Adapted) follows a modern CI/CD (Continuous Integration/Continuous Deployment) pipeline:
Version Control: Git hosted on GitHub. Each feature is developed on a separate branch to prevent breaking the main branch.
Staging: Using Firebase App Distribution, when code is pushed to the develop branch, a new version of the app is automatically built for testing.
Environment Security: All API keys for AI are managed via Environment Variables. For this purpose, flutter_dotenv is used to ensure that no sensitive details are hardcoded.


Chapter 7: Testing and Validation
7.1 Testing Approach
The testing strategy that’ll be implemented is not just about finding bugs, but it is about validating Cognitive Accessibility. V-Model will be used for testing purposes, where every requirement is mapped to a test case.

7.2 Test Types
Unit Testing (Logic Validation)
Isolated tests on the quiz for the profile selection will be done. At least 50+ variations of quiz answers are to be conducted to ensure the algorithm will never produce a “Null” or “Invalid” profile.

Integration Testing (AI Pipeline)
Journey of the PDF, which is the “Extraction-to-prompt-to-UI” flow, will be validated in this testing phase. Here, the entire flow is strictly set to a short “timeout” window.

UI Resilience & Stress Testing
In the Testing phase, we focus on Profile Switching. A manual implementation on the app will be used to force the app to toggle between different UI modes to check for memory leaks or “Widget Overlap,” where UI elements of one mode might accidentally persist in the other.

Heuristic Evaluation (UAT)
A “Cognitive Walkthrough” will be conducted where a user attempts to complete a study module. User struggle points will be noted down, such as too many choices or too many buttons.


7.3 Acceptance Criteria
The system can be accepted after it passes all of the following Quality Gates:
Functional Gate: All core functional requirements must achieve 100% success rate in a controlled environment
Accessibility Gate: The app should pass the “Accessibility Scanner” check with Zero “High Priority” contract or touch-target errors.
Safety Gate: The AI prompt must include “Safety Rails” that prevent the generation of harmful, irrelevant content.
Performance Testing: The app must maintain 60FPS(Frames Per Second) during animations to prevent visual stuttering.





