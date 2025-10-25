package com.selimhorri.app.helper;

import com.selimhorri.app.domain.Credential;
import com.selimhorri.app.domain.User;
import com.selimhorri.app.dto.CredentialDto;
import com.selimhorri.app.dto.UserDto;

public interface UserMappingHelper {

	public static UserDto map(final User user) {
		if (user == null) {
			return null;
		}

		// Manejar el caso donde credential es null
		CredentialDto credentialDto = null;
		if (user.getCredential() != null) {
			credentialDto = CredentialDto.builder()
					.credentialId(user.getCredential().getCredentialId())
					.username(user.getCredential().getUsername())
					.password(user.getCredential().getPassword())
					.roleBasedAuthority(user.getCredential().getRoleBasedAuthority())
					.isEnabled(user.getCredential().getIsEnabled())
					.isAccountNonExpired(user.getCredential().getIsAccountNonExpired())
					.isAccountNonLocked(user.getCredential().getIsAccountNonLocked())
					.isCredentialsNonExpired(user.getCredential().getIsCredentialsNonExpired())
					.build();
		}

		return UserDto.builder()
				.userId(user.getUserId())
				.firstName(user.getFirstName())
				.lastName(user.getLastName())
				.imageUrl(user.getImageUrl())
				.email(user.getEmail())
				.phone(user.getPhone())
				.credentialDto(credentialDto)
				.build();
	}

	public static User map(final UserDto userDto) {
		// Crear el usuario primero
		User user = User.builder()
				.userId(userDto.getUserId())
				.firstName(userDto.getFirstName())
				.lastName(userDto.getLastName())
				.imageUrl(userDto.getImageUrl())
				.email(userDto.getEmail())
				.phone(userDto.getPhone())
				.build();

		// Crear el credential
		Credential credential = Credential.builder()
				.credentialId(userDto.getCredentialDto().getCredentialId())
				.username(userDto.getCredentialDto().getUsername())
				.password(userDto.getCredentialDto().getPassword())
				.roleBasedAuthority(userDto.getCredentialDto().getRoleBasedAuthority())
				.isEnabled(userDto.getCredentialDto().getIsEnabled())
				.isAccountNonExpired(userDto.getCredentialDto().getIsAccountNonExpired())
				.isAccountNonLocked(userDto.getCredentialDto().getIsAccountNonLocked())
				.isCredentialsNonExpired(userDto.getCredentialDto().getIsCredentialsNonExpired())
				.user(user) // ⚠️ IMPORTANTE: Establecer la referencia al user
				.build();

		// Establecer el credential en el user
		user.setCredential(credential);

		return user;
	}

}
