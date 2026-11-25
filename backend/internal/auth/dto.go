package auth

type LoginRequest struct {
	Identifier string `json:"identifier"`
	Password   string `json:"password"`
	meta       clientMeta
}

type RegisterRequest struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
	Email     string `json:"email"`
	Phone     string `json:"phone"`
	Password  string `json:"password"`
	Role      string `json:"role"`
	meta      clientMeta
}

type UpdateProfileRequest struct {
	FirstName string `json:"first_name"`
	LastName  string `json:"last_name"`
}

type UserResponse struct {
	ID                 int64   `json:"id"`
	Email              string  `json:"email"`
	Role               string  `json:"role"`
	FirstName          string  `json:"first_name"`
	LastName           string  `json:"last_name"`
	AvatarURL          *string `json:"avatar_url"`
	InstructorVerified bool    `json:"instructor_verified"`
}

type AuthTokenResponse struct {
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	User         UserResponse `json:"user"`
}

func toUserResponse(u User) UserResponse {
	avatarURL := u.AvatarURL
	return UserResponse{
		ID: u.ID, Email: u.Email, Role: u.Role,
		FirstName: u.FirstName, LastName: u.LastName,
		AvatarURL:          &avatarURL,
		InstructorVerified: u.InstructorVerified,
	}
}
