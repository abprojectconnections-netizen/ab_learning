package auth

type User struct {
	ID                 int64  `json:"id"`
	Email              string `json:"email"`
	Role               string `json:"role"`
	FirstName          string `json:"first_name"`
	LastName           string `json:"last_name"`
	AvatarURL          string `json:"avatar_url"`
	InstructorVerified bool   `json:"instructor_verified"`
}

type RefreshRequest struct {
	RefreshToken string `json:"refresh_token"`
}
