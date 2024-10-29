Self Service Portal for Persona Change Requests

Persona Change Request app where users in a UAT (User Acceptance Testing) environment could quickly switch between different predefined personas. A Persona is essentially a combination of attributes, including profile, permission sets, permission set groups, user attributes (fields, permissions, etc.), and public group assignments. The purpose is to enable users to test various roles without having to manually configure access for each scenario. These personas are configured via Custom Metadata Types that get dynamically pulled and validated through the Apps Vf Page After testing, users should be able to revert to their original setup (original persona) without losing any customized or elevated permissions they had before switching personas. This makes the app useful for preserving unique setups while allowing dynamic persona switching. Finally, I added a MirrorAs feature, which allows users to mirror the access of another user, particularly useful when dealing with users who have highly specialized access setups.

Issues Encountered: Mixed DML Operation Error: This occurred when trying to update setup objects (like permission set assignments) and non-setup objects (like the Persona Change Request record) in the same transaction. Salesforce doesn't allow this, leading to the error: MIXED_DML_OPERATION. Inability to Modify Profiles: Even after fixing the DML issue, another problem arose where the trigger-based request would allow everything except modifying a user’s profile.

Solution: To address these challenges: I moved the user access modifications to a future method to isolate the updates of setup objects and non-setup objects into separate transactions. I implemented a platform event to handle modifications on user records with elevated permissions (such as a sysadmin). This ensures that both permission set assignments and profile changes can be applied without hitting restrictions.

Workflow: Visualforce page (Choose a Persona, validations) → Submit Request (creates a custom object record: Persona Change Request) → Persona Change Request Handler class → Inserts a platform event (PersonaChangeRequestEvent__e) → Calls UpdatePersona code → Future method updates the status on the Persona Change Request record.

App Consists of: VF page, Custom Metadata Types, Custom Object, Apex Trigger, Platform Event Object, Platform Trigger, Apex Classes and PermissionSet for access
