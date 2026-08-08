CREATE OR ALTER PROCEDURE USP_AddUser
	@user_id CHAR(8),
	@surname NVARCHAR(30),
	@given_name NVARCHAR(20),
	@email NVARCHAR(255),
	@phone_number VARCHAR(10),
	@user_role_code VARCHAR(20),
	@department_code VARCHAR(20) = NULL
AS
BEGIN
	BEGIN TRANSACTION;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.UserRole
		WHERE user_role_code = @user_role_code
	)
	THROW 52001, 'Invalid user role', 1;

	IF (@department_code IS NULL AND @user_role_code = 'STUDENT')
	THROW 52026, 'Department was not provided for non-facility staff', 1;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.Department
		WHERE department_code = @department_code
	)
	THROW 52002, 'Invalid department', 1;

	DECLARE @user_role_id AS TINYINT = (
		SELECT user_role_id
		FROM lookup_table.UserRole
		WHERE user_role_code = @user_role_code
	);
	DECLARE @department_id AS TINYINT = (
		SELECT department_id
		FROM lookup_table.Department
		WHERE department_code = @department_code
	);
	DECLARE @user_status_id AS TINYINT = (
		SELECT user_status_id
		FROM lookup_table.UserStatus
		WHERE user_status_code = 'ACTIVE'
	);

	INSERT INTO [User] (user_id, surname, given_name, email, phone_number, user_role_id, department_id, user_status_id)
	VALUES (@user_id, @surname, @given_name, @email, @phone_number, @user_role_id, @department_id, @user_status_id);
	COMMIT;
END
GO

CREATE OR ALTER PROCEDURE USP_AddSpace
	@space_id VARCHAR(10),
	@space_name NVARCHAR(30),
	@space_type_code VARCHAR(20),
	@building CHAR(1),
	@floor TINYINT,
	@room_number TINYINT,
	@capacity SMALLINT,
	@space_policy_id CHAR(5)
AS
BEGIN
	BEGIN TRANSACTION;

	IF NOT EXISTS (
		SELECT 1
		FROM lookup_table.SpaceType
		WHERE space_type_code = @space_type_code
	)
	THROW 52003, 'Invalid space type', 1;

	DECLARE @space_type_id AS TINYINT = (
		SELECT space_type_id
		FROM lookup_table.SpaceType
		WHERE space_type_code = @space_type_code
	);
	DECLARE @space_status_id AS TINYINT = (
		SELECT space_status_id
		FROM lookup_table.SpaceStatus
		WHERE space_status_code = 'AVAILABLE'
	);

	INSERT INTO Space (space_id, space_name, space_type_id, building, floor, room_number, capacity, space_status_id, space_policy_id)
	VALUES (@space_id, @space_name, @space_type_id, @building, @floor, @room_number, @capacity, @space_status_id, @space_policy_id);
	COMMIT;
END
GO