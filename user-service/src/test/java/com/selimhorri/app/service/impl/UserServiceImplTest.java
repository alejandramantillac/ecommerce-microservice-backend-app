package com.selimhorri.app.service.impl;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.selimhorri.app.domain.Credential;
import com.selimhorri.app.domain.RoleBasedAuthority;
import com.selimhorri.app.domain.User;
import com.selimhorri.app.dto.CredentialDto;
import com.selimhorri.app.dto.UserDto;
import com.selimhorri.app.exception.wrapper.UserObjectNotFoundException;
import com.selimhorri.app.repository.UserRepository;

/**
 * Unit tests for UserServiceImpl
 * Tests validate individual component functionality without external dependencies
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("User Service Unit Tests")
class UserServiceImplTest {

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private UserServiceImpl userService;

    private User testUser;
    private UserDto testUserDto;
    private Credential credential;

    @BeforeEach
    void setUp() {
        // Setup test data
        credential = Credential.builder()
            .credentialId(1)
            .username("testuser")
            .password("password123")
            .roleBasedAuthority(RoleBasedAuthority.ROLE_USER)
            .isEnabled(true)
            .isAccountNonExpired(true)
            .isAccountNonLocked(true)
            .isCredentialsNonExpired(true)
            .build();

        testUser = User.builder()
            .userId(1)
            .firstName("John")
            .lastName("Doe")
            .email("john.doe@example.com")
            .phone("+1234567890")
            .imageUrl("http://example.com/image.jpg")
            .credential(credential)
            .build();

        testUserDto = UserDto.builder()
            .userId(1)
            .firstName("John")
            .lastName("Doe")
            .email("john.doe@example.com")
            .phone("+1234567890")
            .imageUrl("http://example.com/image.jpg")
            .credentialDto(CredentialDto.builder()
                .username("testuser")
                .password("password123")
                .roleBasedAuthority(RoleBasedAuthority.ROLE_USER)
                .isEnabled(true)
                .isAccountNonExpired(true)
                .isAccountNonLocked(true)
                .isCredentialsNonExpired(true)
                .build())
            .build();
    }

    @Test
    @DisplayName("Test 1: Find all users should return list of UserDto")
    void testFindAll_ShouldReturnListOfUsers() {
        // Given
        User user2 = User.builder()
            .userId(2)
            .firstName("Jane")
            .lastName("Smith")
            .email("jane.smith@example.com")
            .phone("+0987654321")
            .credential(credential)
            .build();

        when(userRepository.findAll()).thenReturn(Arrays.asList(testUser, user2));

        // When
        List<UserDto> result = userService.findAll();

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(2, result.size(), "Should return 2 users");
        verify(userRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Test 2: Find user by ID should return UserDto when user exists")
    void testFindById_WhenUserExists_ShouldReturnUserDto() {
        // Given
        Integer userId = 1;
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));

        // When
        UserDto result = userService.findById(userId);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testUser.getUserId(), result.getUserId(), "User IDs should match");
        assertEquals(testUser.getEmail(), result.getEmail(), "Emails should match");
        verify(userRepository, times(1)).findById(userId);
    }

    @Test
    @DisplayName("Test 3: Find user by ID should throw exception when user not found")
    void testFindById_WhenUserNotExists_ShouldThrowException() {
        // Given
        Integer userId = 999;
        when(userRepository.findById(userId)).thenReturn(Optional.empty());

        // When & Then
        UserObjectNotFoundException exception = assertThrows(
            UserObjectNotFoundException.class,
            () -> userService.findById(userId),
            "Should throw UserObjectNotFoundException"
        );

        assertTrue(exception.getMessage().contains("not found"), "Exception message should contain 'not found'");
        verify(userRepository, times(1)).findById(userId);
    }

    @Test
    @DisplayName("Test 4: Save user should persist and return UserDto")
    void testSave_ShouldPersistAndReturnUserDto() {
        // Given
        when(userRepository.save(any(User.class))).thenReturn(testUser);

        // When
        UserDto result = userService.save(testUserDto);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testUserDto.getFirstName(), result.getFirstName(), "First names should match");
        assertEquals(testUserDto.getLastName(), result.getLastName(), "Last names should match");
        verify(userRepository, times(1)).save(any(User.class));
    }

    @Test
    @DisplayName("Test 5: Update user should modify and return updated UserDto")
    void testUpdate_ShouldModifyAndReturnUserDto() {
        // Given
        UserDto updatedUserDto = UserDto.builder()
            .userId(1)
            .firstName("John Updated")
            .lastName("Doe Updated")
            .email("john.updated@example.com")
            .phone("+1111111111")
            .credentialDto(CredentialDto.builder()
                .credentialId(1)
                .username("testuser")
                .password("password123")
                .roleBasedAuthority(RoleBasedAuthority.ROLE_USER)
                .isEnabled(true)
                .isAccountNonExpired(true)
                .isAccountNonLocked(true)
                .isCredentialsNonExpired(true)
                .build())
            .build();

        User updatedUser = User.builder()
            .userId(1)
            .firstName("John Updated")
            .lastName("Doe Updated")
            .email("john.updated@example.com")
            .phone("+1111111111")
            .credential(credential)
            .build();

        when(userRepository.save(any(User.class))).thenReturn(updatedUser);

        // When
        UserDto result = userService.update(updatedUserDto);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals("John Updated", result.getFirstName(), "First name should be updated");
        assertEquals("john.updated@example.com", result.getEmail(), "Email should be updated");
        verify(userRepository, times(1)).save(any(User.class));
    }

    @Test
    @DisplayName("Test 6: Delete user by ID should invoke repository delete")
    void testDeleteById_ShouldInvokeRepositoryDelete() {
        // Given
        Integer userId = 1;
        doNothing().when(userRepository).deleteById(userId);

        // When
        userService.deleteById(userId);

        // Then
        verify(userRepository, times(1)).deleteById(userId);
    }

    @Test
    @DisplayName("Test 7: Find user by username should return UserDto when user exists")
    void testFindByUsername_WhenUserExists_ShouldReturnUserDto() {
        // Given
        String username = "testuser";
        when(userRepository.findByCredentialUsername(username)).thenReturn(Optional.of(testUser));

        // When
        UserDto result = userService.findByUsername(username);

        // Then
        assertNotNull(result, "Result should not be null");
        assertEquals(testUser.getUserId(), result.getUserId(), "User IDs should match");
        verify(userRepository, times(1)).findByCredentialUsername(username);
    }

    @Test
    @DisplayName("Test 8: Find user by username should throw exception when user not found")
    void testFindByUsername_WhenUserNotExists_ShouldThrowException() {
        // Given
        String username = "nonexistent";
        when(userRepository.findByCredentialUsername(username)).thenReturn(Optional.empty());

        // When & Then
        UserObjectNotFoundException exception = assertThrows(
            UserObjectNotFoundException.class,
            () -> userService.findByUsername(username),
            "Should throw UserObjectNotFoundException"
        );

        assertTrue(exception.getMessage().contains("not found"), "Exception message should contain 'not found'");
        verify(userRepository, times(1)).findByCredentialUsername(username);
    }

    @Test
    @DisplayName("Test 9: Find all users with empty list should return empty result")
    void testFindAll_WhenNoUsers_ShouldReturnEmptyList() {
        // Given
        when(userRepository.findAll()).thenReturn(Arrays.asList());

        // When
        List<UserDto> result = userService.findAll();

        // Then
        assertNotNull(result, "Result should not be null");
        assertTrue(result.isEmpty(), "Result should be empty");
        verify(userRepository, times(1)).findAll();
    }

    @Test
    @DisplayName("Test 10: Update user with userId should fetch and update user")
    void testUpdateWithUserId_ShouldFetchAndUpdateUser() {
        // Given
        Integer userId = 1;
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        when(userRepository.save(any(User.class))).thenReturn(testUser);

        // When
        UserDto result = userService.update(userId, testUserDto);

        // Then
        assertNotNull(result, "Result should not be null");
        verify(userRepository, times(1)).findById(userId);
        verify(userRepository, times(1)).save(any(User.class));
    }
}

